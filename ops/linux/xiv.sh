#!/usr/bin/env bash
# xiv: run the XIVLegacy server on a Linux machine set up by ops/linux/install.sh.
# The Linux twin of the NUC's ops\xiv.cmd: the same verbs, one instance per machine.
#
#   xiv status                      services, ports, players online, memory, deployed build
#   xiv deploy [REF]                install the CI build of a branch, tag, commit or PR
#                                   (default: DEFAULT_REF in xiv.conf), back up first,
#                                   roll back if the new build doesn't come up
#   xiv deploy --file BUNDLE.tar.gz install a bundle you copied here (checks its .sha256 if next to it)
#   xiv deploy --dir UNPACKED/      install an unpacked bundle
#   xiv start | stop | restart      'stop' also keeps it from starting at boot; 'start' undoes that
#   xiv logs [web|lobby|world|map] [-n 200]
#   xiv backup                      gzip'd dump in /var/backups/xivlegacy
#   xiv import DUMP.sql[.gz]        replace the database with a dump (e.g. a NUC backup);
#                                   backs up the current one first
#   xiv hold [REASON] | release     block deploys (and imports) while held; --force overrides
#   xiv setgm "First Last" LEVEL    GM level 0-4 for that character's account
#   xiv sql "SELECT ..."            run SQL against the game database
#
# Settings: /etc/xivlegacy/xiv.conf. Extra server settings (modules.toml, commands.toml,
# bugreport.toml, jail.toml...): put them in /etc/xivlegacy/settings/; '<name>.extra.toml'
# is appended to the generated file of that name (web, lobby, world, map, servers).
set -euo pipefail

ETC=/etc/xivlegacy
OPT=/opt/xivlegacy
VAR=/var/lib/xivlegacy
OPS_STATE=/var/lib/xivlegacy-ops
BACKUPS=/var/backups/xivlegacy
LOGDIR=/var/log/xivlegacy
SVC_USER=xivlegacy
SERVICES="web lobby world map"
LOCK=/run/xivlegacy.lock

# Defaults; xiv.conf overrides them.
PUBLIC_ADDRESS=127.0.0.1
WORLD_NAME=Fernehalwes
WEB_PORT=54993
LOBBY_PORT=54994
WORLD_PORT=54992
MAP_PORT=1989
BIND_IP=0.0.0.0
RUST_LOG="info"
GITHUB_REPO="tagban/xivlegacy-server"
DEFAULT_REF="develop"
KEEP_BACKUP_DAYS=14
# shellcheck disable=SC1091
[ -r "$ETC/xiv.conf" ] && . "$ETC/xiv.conf"
DB_NAME=xivlegacy

say()  { printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; [ -w "$OPS_STATE" ] && printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$OPS_STATE/xiv.log" || true; }
warn() { say "warning: $*" >&2; }
die()  { say "error: $*" >&2; exit 1; }

need_root() { [ "$(id -u)" -eq 0 ] || die "run as root (sudo xiv $*)"; mkdir -p "$OPS_STATE"; }

if [ -d /run/systemd/system ]; then INIT=systemd; else INIT=openrc; fi

MARIADB="$(command -v mariadb || command -v mysql || true)"
MARIADUMP="$(command -v mariadb-dump || command -v mysqldump || true)"

# ---------------------------------------------------------------- state
state_get() { sed -n "s/^$1=//p" "$OPS_STATE/state" 2>/dev/null | tail -n1; }
state_set() {
    mkdir -p "$OPS_STATE"
    touch "$OPS_STATE/state"
    grep -v "^$1=" "$OPS_STATE/state" > "$OPS_STATE/state.tmp" || true
    printf '%s=%s\n' "$1" "$2" >> "$OPS_STATE/state.tmp"
    mv -f "$OPS_STATE/state.tmp" "$OPS_STATE/state"
}

with_lock() {
    exec 9>"$LOCK"
    flock -w 3600 9 || die "another xiv command is still running"
}

# ---------------------------------------------------------------- database
sql_root() { "$MARIADB" --default-character-set=utf8mb4 "$@"; }
sql_value() { sql_root -N -B -D "$DB_NAME" -e "$1" 2>/dev/null; }
db_exists() { [ "$(sql_root -N -B -e "SELECT COUNT(*) FROM information_schema.schemata WHERE schema_name='$DB_NAME'")" = 1 ]; }
db_has_tables() { [ "$(sql_root -N -B -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$DB_NAME'")" -gt 0 ]; }

# Version of the MariaDB server as a number: 10.11.6 -> 101106.
mariadb_version_num() {
    sql_root -N -B -e 'SELECT VERSION()' | sed 's/-.*//' | awk -F. '{ printf "%d%02d%02d\n", $1, $2, $3 }'
}

backup_db() {
    if ! db_exists || ! db_has_tables; then say "no database to back up yet"; return 0; fi
    mkdir -p "$BACKUPS"
    chmod 0750 "$BACKUPS"
    local f
    f="$BACKUPS/$DB_NAME-$(date +%Y%m%d-%H%M%S).sql.gz"
    (umask 077; "$MARIADUMP" --single-transaction --triggers --hex-blob --default-character-set=utf8mb4 "$DB_NAME" | gzip -6 > "$f.part")
    mv -f "$f.part" "$f"
    say "backed up $DB_NAME to $f ($(du -h "$f" | cut -f1))"
    # Keep KEEP_BACKUP_DAYS days, and never fewer than the 7 newest.
    # shellcheck disable=SC2012
    ls -1t "$BACKUPS"/*.sql.gz 2>/dev/null | tail -n +8 | while read -r old; do
        if [ -n "$(find "$old" -mtime +"$KEEP_BACKUP_DAYS" 2>/dev/null)" ]; then rm -f "$old"; fi
    done
    LAST_BACKUP="$f"
}

# Load a dump (.sql or .sql.gz) into a fresh database. Dumps from a newer MariaDB
# (the NUC runs 12.x) are made loadable on older ones: the 'sandbox mode' first
# line older clients reject is dropped, and the uca1400 collations (MariaDB 10.10+)
# become utf8mb4_unicode_ci where the server doesn't have them.
import_dump() {
    local dump="$1" ver filter
    ver="$(mariadb_version_num)"
    filter='1{/enable the sandbox mode/d;}'
    if [ "$ver" -lt 101000 ]; then
        filter="$filter;s/utf8mb4_uca1400_[a-z_]*/utf8mb4_unicode_ci/g;s/uca1400_[a-z_]*/utf8mb4_unicode_ci/g"
    fi
    say "loading $dump into $DB_NAME"
    sql_root -e "DROP DATABASE IF EXISTS \`$DB_NAME\`; CREATE DATABASE \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    case "$dump" in
        *.gz) gzip -dc "$dump" ;;
        *)    cat "$dump" ;;
    esac | sed -e "$filter" | sql_root "$DB_NAME"
    say "loaded: $(sql_value 'SELECT COUNT(*) FROM users') accounts, $(sql_value 'SELECT COUNT(*) FROM characters') characters"
}

# ---------------------------------------------------------------- settings
write_settings() {
    local s="$VAR/settings" cur="$OPT/current" f
    mkdir -p "$s"
    # The servers read ./scripts/lua, ./modules and settings/default from the
    # deployed bundle through these links, so switching 'current' switches all.
    ln -sfn "$cur/settings/default" "$s/default"
    ln -sfn "$cur/scripts" "$VAR/scripts"
    ln -sfn "$cur/modules" "$VAR/modules"
    local hdr="# Written by xiv from /etc/xivlegacy/xiv.conf at every start; edits here are lost.
# Extra keys: /etc/xivlegacy/settings/<name>.extra.toml (don't repeat [server]).
# The database URL comes from /etc/xivlegacy/db.env (XIVLEGACY_DB_URL).
"
    printf '%s\n[server]\nbind_ip = "%s"\nport = %s\n' "$hdr" "$BIND_IP" "$WEB_PORT" > "$s/web.toml"
    printf '%s\n[server]\nbind_ip = "%s"\nport = %s\n' "$hdr" "$BIND_IP" "$LOBBY_PORT" > "$s/lobby.toml"
    printf '%s\n[server]\nbind_ip = "%s"\nport = %s\nworld_id = 1\n' "$hdr" "$BIND_IP" "$WORLD_PORT" > "$s/world.toml"
    printf '%s\n[server]\nbind_ip = "127.0.0.1"\nport = %s\nworld_id = 1\n' "$hdr" "$MAP_PORT" > "$s/map.toml"
    printf '%s\n[[servers]]\nid = 1\nname = "%s"\naddress = "%s"\nport = %s\nlist_position = 1\nmax_chars = 5000\nis_active = true\n' \
        "$hdr" "$WORLD_NAME" "$PUBLIC_ADDRESS" "$WORLD_PORT" > "$s/servers.toml"
    if [ -d "$ETC/settings" ]; then
        for f in "$ETC"/settings/*.toml; do
            [ -e "$f" ] || continue
            case "$(basename "$f")" in
                *.extra.toml)
                    local base; base="$(basename "$f" .extra.toml)"
                    [ -f "$s/$base.toml" ] && printf '\n# --- from %s\n%s\n' "$f" "$(cat "$f")" >> "$s/$base.toml" ;;
                web.toml|lobby.toml|world.toml|map.toml|servers.toml)
                    warn "ignoring $f: use $(basename "$f" .toml).extra.toml for additions" ;;
                *) install -m 0644 "$f" "$s/" ;;
            esac
        done
    fi
    printf 'RUST_LOG=%s\n' "$RUST_LOG" > "$VAR/runtime.env"
    # Root's files: the servers only read them.
    chown -h root:root "$s" "$s"/*.toml "$VAR/runtime.env" 2>/dev/null || true
    chmod 0755 "$s"
    chmod 0644 "$s"/*.toml "$VAR/runtime.env"
}

# ---------------------------------------------------------------- services
svc_active() {
    if [ "$INIT" = systemd ]; then systemctl is-active -q "xivlegacy-$1.service"
    else rc-service "xivlegacy-$1" status >/dev/null 2>&1; fi
}

svc_pid() {
    if [ "$INIT" = systemd ]; then
        systemctl show -p MainPID --value "xivlegacy-$1.service" 2>/dev/null | grep -v '^0$' || true
    else
        pgrep -f "^$OPT/[^ ]*/bin/$1-server" | head -n1 || true
    fi
}

listening() { ss -Hltn 2>/dev/null | awk '{print $4}' | grep -Eq "[:.]$1\$"; }

ports_up() {
    local n=0
    listening "$WEB_PORT" && n=$((n+1))
    listening "$LOBBY_PORT" && n=$((n+1))
    listening "$WORLD_PORT" && n=$((n+1))
    listening "$MAP_PORT" && n=$((n+1))
    echo "$n"
}

start_all() {
    [ -x "$OPT/current/bin/map-server" ] || die "nothing deployed yet: xiv deploy"
    write_settings
    if [ "$INIT" = systemd ]; then
        systemctl reset-failed 'xivlegacy-*' 2>/dev/null || true
        systemctl enable -q xivlegacy.target
        systemctl start --no-block xivlegacy.target 9>&-
    else
        for s in $SERVICES; do rc-update add "xivlegacy-$s" default >/dev/null 2>&1 || true; done
        # 9>&-: the services must not inherit xiv's lock (OpenRC starts them as our children).
        for s in $SERVICES; do rc-service "xivlegacy-$s" start >/dev/null 9>&- || return 1; done
    fi
    wait_up 900
}

stop_all() {
    if [ "$INIT" = systemd ]; then
        systemctl stop xivlegacy.target xivlegacy-map xivlegacy-world xivlegacy-lobby xivlegacy-web 2>/dev/null || true
    else
        for s in map world lobby web; do rc-service "xivlegacy-$s" stop >/dev/null 2>&1 9>&- || true; done
    fi
    local i
    for i in $(seq 30); do [ "$(ports_up)" -eq 0 ] && break; sleep 1; done
    [ "$(ports_up)" -eq 0 ] || warn "some ports are still in use after stopping"
}

# Wait until every service runs and all four ports listen.
wait_up() {
    local deadline=$(( $(date +%s) + $1 )) s down
    while :; do
        down=""
        for s in $SERVICES; do svc_active "$s" || down="$down $s"; done
        if [ -z "$down" ] && [ "$(ports_up)" -eq 4 ]; then say "up: $PUBLIC_ADDRESS (web :$WEB_PORT, lobby :$LOBBY_PORT, world :$WORLD_PORT, map 127.0.0.1:$MAP_PORT)"; return 0; fi
        if [ "$INIT" = systemd ]; then
            for s in $SERVICES; do
                if systemctl is-failed -q "xivlegacy-$s.service"; then say "$s failed to start"; show_logs "$s" 25; return 1; fi
            done
        fi
        if [ "$(date +%s)" -gt "$deadline" ]; then say "not up after $1 s (waiting for:${down:- ports})"; for s in $SERVICES; do show_logs "$s" 15; done; return 1; fi
        sleep 2
    done
}

show_logs() {
    local s="$1" n="${2:-80}"
    echo "    --- $s (last $n lines)"
    if [ "$INIT" = systemd ]; then
        journalctl -u "xivlegacy-$s.service" -n "$n" --no-pager -o cat 2>/dev/null | sed 's/^/    /'
    else
        tail -n "$n" "$LOGDIR/$s.log" 2>/dev/null | sed 's/^/    /'
    fi
}

# ---------------------------------------------------------------- deploy
github_token() {
    if [ -n "${GITHUB_TOKEN:-}" ]; then printf '%s' "$GITHUB_TOKEN"; return; fi
    [ -r "$ETC/github-token" ] && tr -d ' \n\r' < "$ETC/github-token"
}

gh_api() {
    local token; token="$(github_token)"
    [ -n "$token" ] || die "downloading builds needs a GitHub token in $ETC/github-token (see README); or copy a bundle here and use --file"
    curl -fsSL -H "Authorization: Bearer $token" -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" "https://api.github.com/$1"
}

resolve_ref() {
    local ref="$1"
    if [[ "$ref" =~ ^(pr/|#)?([0-9]+)$ ]]; then
        gh_api "repos/$GITHUB_REPO/pulls/${BASH_REMATCH[2]}" | jq -r .head.sha
    else
        gh_api "repos/$GITHUB_REPO/commits/$ref" | jq -r .sha
    fi
}

# Unpack + verify a bundle tarball into $OPT/releases/<sha>; prints that folder.
unpack_bundle() {
    local tgz="$1" tmp sha dir
    if [ -f "$tgz.sha256" ]; then
        (cd "$(dirname "$tgz")" && sha256sum -c "$(basename "$tgz").sha256" >/dev/null 2>&1) || die "$tgz doesn't match $tgz.sha256"
    fi
    tmp="$(mktemp -d "$OPT/releases/.unpack.XXXXXX")"
    tar -xzf "$tgz" -C "$tmp"
    dir="$(find "$tmp" -mindepth 1 -maxdepth 1 -type d | head -n1)"
    [ -f "$dir/BUILD" ] || { rm -rf "$tmp"; die "$tgz isn't a server bundle (no BUILD file)"; }
    install_dir "$dir"
    rm -rf "$tmp"
}

# Verify an unpacked bundle and copy it to $OPT/releases/<sha>; sets NEW_RELEASE.
install_dir() {
    local src="$1" sha
    [ -f "$src/BUILD" ] && [ -x "$src/bin/map-server" ] || die "$src isn't an unpacked server bundle"
    (cd "$src" && sha256sum -c SHA256SUMS >/dev/null 2>&1) || die "files in $src don't match its SHA256SUMS"
    sha="$(sed -n 's/^commit=//p' "$src/BUILD")"
    [ -n "$sha" ] || die "$src/BUILD has no commit"
    NEW_RELEASE="$OPT/releases/$sha"
    if [ -f "$NEW_RELEASE/SHA256SUMS" ] && cmp -s "$src/SHA256SUMS" "$NEW_RELEASE/SHA256SUMS"; then
        :   # already installed, file for file
    elif [ "$(cd "$src" && pwd -P)" != "$(cd "$NEW_RELEASE" 2>/dev/null && pwd -P || true)" ]; then
        rm -rf "$NEW_RELEASE.tmp"
        cp -a "$src" "$NEW_RELEASE.tmp"
        rm -rf "$NEW_RELEASE"
        mv "$NEW_RELEASE.tmp" "$NEW_RELEASE"
    fi
    chown -R root:root "$NEW_RELEASE"
    chmod -R go-w "$NEW_RELEASE"
}

download_build() {
    local ref="$1" sha name url tmp
    sha="$(resolve_ref "$ref")"
    [[ "$sha" =~ ^[0-9a-f]{40}$ ]] || die "can't find '$ref' in $GITHUB_REPO"
    if [ -x "$OPT/releases/$sha/bin/map-server" ]; then
        say "$ref = ${sha:0:10}: already downloaded"
        NEW_RELEASE="$OPT/releases/$sha"; return
    fi
    name="xivlegacy-server-linux-x86_64-$sha"
    url="$(gh_api "repos/$GITHUB_REPO/actions/artifacts?name=$name&per_page=5" |
        jq -r '[.artifacts[] | select(.expired | not)][0].archive_download_url // empty')"
    [ -n "$url" ] || die "no Linux build of $ref (${sha:0:10}) yet. Pushes to develop build one; for another branch run the 'Linux server bundle' workflow (GitHub Actions tab) with ref=$ref, wait for it, then deploy again"
    say "downloading $name"
    tmp="$(mktemp -d)"
    curl -fsSL -H "Authorization: Bearer $(github_token)" -o "$tmp/a.zip" "$url"
    (cd "$tmp" && unzip -q a.zip)
    unpack_bundle "$tmp/$name.tar.gz"
    rm -rf "$tmp"
}

deploy() {
    local ref="" file="" dir="" force=0
    while [ $# -gt 0 ]; do
        case "$1" in
            --file) file="$2"; shift 2 ;;
            --dir) dir="$2"; shift 2 ;;
            --force) force=1; shift ;;
            -*) die "unknown option $1" ;;
            *) ref="$1"; shift ;;
        esac
    done
    with_lock
    if [ "$(state_get held)" = 1 ] && [ "$force" = 0 ]; then die "held ($(state_get hold_reason)); 'xiv release' first, or --force"; fi
    mkdir -p "$OPT/releases"
    NEW_RELEASE=""
    if [ -n "$dir" ]; then install_dir "$dir"
    elif [ -n "$file" ]; then unpack_bundle "$(cd "$(dirname "$file")" && pwd)/$(basename "$file")"
    else download_build "${ref:-$DEFAULT_REF}"
    fi
    local new="$NEW_RELEASE" old="" sha
    sha="$(basename "$new")"
    [ -L "$OPT/current" ] && old="$(readlink "$OPT/current")"
    say "deploying ${sha:0:10} ($(sed -n 's/^ref=//p' "$new/BUILD"), built $(sed -n 's/^built=//p' "$new/BUILD"))"
    backup_db
    stop_all
    ln -sfn "$new" "$OPT/current"
    # The ops scripts ride in the bundle; keep the installed 'xiv' in step.
    if [ -f "$new/ops/linux/xiv.sh" ]; then install -m 0755 "$new/ops/linux/xiv.sh" /usr/local/sbin/xiv.new && mv -f /usr/local/sbin/xiv.new /usr/local/sbin/xiv; fi
    state_set previous "$old"
    state_set stopped 0
    if start_all; then
        state_set deployed_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        say "deployed ${sha:0:10} OK"
        # Keep the 5 newest releases plus whatever is current/previous.
        # shellcheck disable=SC2012
        ls -1dt "$OPT"/releases/*/ 2>/dev/null | sed 's#/$##' | tail -n +6 | while read -r r; do
            [ "$r" = "$new" ] || [ "$r" = "$old" ] || rm -rf "$r"
        done
        return 0
    fi
    if [ -n "$old" ] && [ -d "$old" ]; then
        say "the new build didn't come up; rolling back to $(basename "$old" | cut -c1-10)"
        stop_all
        ln -sfn "$old" "$OPT/current"
        state_set previous "$new"
        if start_all; then say "rolled back; running $(basename "$old" | cut -c1-10). The pre-deploy backup is ${LAST_BACKUP:-(none)}"
        else say "ROLLBACK FAILED TOO; the server is down. Pre-deploy backup: ${LAST_BACKUP:-(none)}"; fi
        die "deploy of ${sha:0:10} failed"
    fi
    die "${sha:0:10} didn't come up (see xiv logs)"
}

# ---------------------------------------------------------------- status
status() {
    local s pid rss state online cur
    if [ "$INIT" = systemd ]; then
        printf 'MariaDB: %s\n' "$(systemctl is-active mariadb 2>/dev/null || true)"
    else
        printf 'MariaDB: %s\n' "$(rc-service mariadb status 2>/dev/null | sed 's/.*: //' || true)"
    fi
    cur="$(readlink "$OPT/current" 2>/dev/null || true)"
    if [ -n "$cur" ]; then
        printf 'Build:   %s  ref %s  built %s  deployed %s\n' "$(sed -n 's/^commit=//p' "$cur/BUILD" | cut -c1-10)" \
            "$(sed -n 's/^ref=//p' "$cur/BUILD")" "$(sed -n 's/^built=//p' "$cur/BUILD")" "$(state_get deployed_at)"
    else
        echo "Build:   nothing deployed yet"
    fi
    printf 'Address: %s  world "%s"\n' "$PUBLIC_ADDRESS" "$WORLD_NAME"
    printf '\n%-7s %-9s %-8s %s\n' Server State PID 'RSS MB'
    for s in $SERVICES; do
        pid="$(svc_pid "$s")"
        if svc_active "$s"; then state=running; else state=stopped; fi
        rss=""
        [ -n "$pid" ] && rss="$(awk '/^VmRSS/ { printf "%.0f", $2/1024 }' "/proc/$pid/status" 2>/dev/null || true)"
        printf '%-7s %-9s %-8s %s\n' "$s" "$state" "${pid:--}" "${rss:--}"
    done
    pid="$(pgrep -x mariadbd || pgrep -x mysqld || true)"
    [ -n "$pid" ] && printf '%-7s %-9s %-8s %s\n' mariadb running "$(echo "$pid" | head -n1)" \
        "$(awk '/^VmRSS/ { printf "%.0f", $2/1024 }' "/proc/$(echo "$pid" | head -n1)/status" 2>/dev/null)"
    online=""
    if [ "$(ports_up)" -gt 0 ]; then online="$(sql_value 'SELECT COUNT(*) FROM world_sessions' || true)"; fi
    printf '\nPorts listening: %s/4   Players online: %s\n' "$(ports_up)" "${online:--}"
    local notes=""
    [ "$(state_get held)" = 1 ] && notes="held: $(state_get hold_reason)"
    [ "$(state_get stopped)" = 1 ] && notes="${notes:+$notes; }stopped by hand (won't start at boot)"
    [ -n "$notes" ] && printf 'Notes: %s\n' "$notes"
    echo
    free -m | sed -n '1,3p'
}

# ---------------------------------------------------------------- _wait-web (the web unit's start check)
# Runs as the service user right after the web server starts: wait for /healthz
# (the database is set up by then), then point server_zones at this map port.
wait_web() {
    local url user pass host port db web_host="$BIND_IP"
    [ "$web_host" = 0.0.0.0 ] && web_host=127.0.0.1
    for _ in $(seq 840); do
        if curl -fs -o /dev/null "http://$web_host:$WEB_PORT/healthz"; then
            url="${XIVLEGACY_DB_URL:-}"
            if [ -n "$url" ] && [ -n "$MARIADB" ]; then
                user="$(printf '%s' "$url" | sed -n 's#^mysql://\([^:@]*\).*#\1#p')"
                pass="$(printf '%s' "$url" | sed -n 's#^mysql://[^:]*:\([^@]*\)@.*#\1#p')"
                host="$(printf '%s' "$url" | sed -n 's#.*@\([^:/]*\).*#\1#p')"
                port="$(printf '%s' "$url" | sed -n 's#.*@[^:/]*:\([0-9]*\)/.*#\1#p')"
                db="$(printf '%s' "$url" | sed -n 's#.*/\([^/?]*\).*#\1#p')"
                MYSQL_PWD="$pass" "$MARIADB" --skip-ssl -h "$host" -P "${port:-3306}" -u "$user" "$db" -e \
                    "UPDATE server_zones SET serverPort = $MAP_PORT WHERE serverIp = '127.0.0.1' AND serverPort BETWEEN 1989 AND 1999 AND serverPort <> $MAP_PORT;" \
                    || echo "warning: couldn't point server_zones at port $MAP_PORT" >&2
            fi
            return 0
        fi
        sleep 1
    done
    echo "the web server didn't answer /healthz within 840 s" >&2
    return 1
}

# ---------------------------------------------------------------- commands
cmd="${1:-status}"
[ $# -gt 0 ] && shift
case "$cmd" in
    status)  need_root status; status ;;
    deploy)  need_root deploy; deploy "$@" ;;
    start)   need_root start; with_lock; state_set stopped 0; start_all ;;
    stop)
        need_root stop; with_lock; state_set stopped 1
        stop_all
        if [ "$INIT" = systemd ]; then systemctl disable -q xivlegacy.target
        else for s in $SERVICES; do rc-update del "xivlegacy-$s" default >/dev/null 2>&1 || true; done; fi
        say "stopped (and won't start at boot until 'xiv start')" ;;
    restart) need_root restart; with_lock; state_set stopped 0; stop_all; start_all ;;
    logs)
        svc=""; n=80
        while [ $# -gt 0 ]; do
            case "$1" in
                -n|--tail|-Tail) n="$2"; shift 2 ;;
                web|lobby|world|map) svc="$1"; shift ;;
                -Service|--service) svc="$2"; shift 2 ;;
                *) die "logs [web|lobby|world|map] [-n LINES]" ;;
            esac
        done
        for s in ${svc:-$SERVICES}; do show_logs "$s" "$n"; done
        [ -z "$svc" ] && [ -f "$OPS_STATE/xiv.log" ] && { echo "    --- xiv.log"; tail -n 15 "$OPS_STATE/xiv.log" | sed 's/^/    /'; }
        ;;
    backup)  need_root backup; backup_db ;;
    import)
        need_root import
        force=0; file=""
        for a in "$@"; do case "$a" in --force) force=1 ;; -File|--file) ;; *) file="$a" ;; esac; done
        [ -n "$file" ] && [ -f "$file" ] || die "import DUMP.sql or DUMP.sql.gz"
        file="$(cd "$(dirname "$file")" && pwd)/$(basename "$file")"
        with_lock
        if [ "$(state_get held)" = 1 ] && [ "$force" = 0 ]; then die "held ($(state_get hold_reason)); 'xiv release' first, or --force"; fi
        stop_all
        backup_db
        import_dump "$file"
        if [ -x "$OPT/current/bin/map-server" ] && [ "$(state_get stopped)" != 1 ]; then start_all; fi
        ;;
    hold)
        need_root hold
        state_set held 1; state_set hold_reason "${*:-held}"; state_set held_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        say "held (${*:-held}); deploys and imports need --force until 'xiv release'" ;;
    release) need_root release; state_set held 0; state_set hold_reason ""; say "released" ;;
    setgm)
        need_root setgm
        name=""; level=""
        while [ $# -gt 0 ]; do
            case "$1" in
                -Name|--name) name="$2"; shift 2 ;;
                -Level|--level) level="$2"; shift 2 ;;
                *) if [ -z "$name" ]; then name="$1"; else level="$1"; fi; shift ;;
            esac
        done
        [ -n "$name" ] && [[ "$level" =~ ^[0-4]$ ]] || die 'setgm "First Last" LEVEL (0-4)'
        safe="${name//\'/\'\'}"
        safe="${safe//\\/\\\\}"
        sql_root -D "$DB_NAME" -e "UPDATE users SET gmLevel = $level WHERE id = (SELECT userId FROM characters WHERE name = '$safe' LIMIT 1);"
        sql_root --table -D "$DB_NAME" -e "SELECT u.username, u.gmLevel, c.name FROM users u JOIN characters c ON c.userId = u.id WHERE c.name = '$safe';"
        say "GM level $level for $name's account (takes effect at their next login)" ;;
    sql)
        need_root sql
        [ "${1:-}" = "-Sql" ] && shift
        [ -n "${1:-}" ] || die 'sql "SELECT ..."'
        sql_root --table -D "$DB_NAME" -e "$1" ;;
    _wait-web) wait_web ;;
    -h|--help|help) sed -n '2,26p' "$0" ;;
    *) die "unknown command '$cmd' (status, deploy, start, stop, restart, logs, backup, import, hold, release, setgm, sql)" ;;
esac
