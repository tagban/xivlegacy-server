#!/bin/sh
# Alpine has no bash out of the box: fetch it, then carry on under bash.
if [ -z "${BASH_VERSION:-}" ]; then
    if ! command -v bash >/dev/null 2>&1 && command -v apk >/dev/null 2>&1; then apk add --no-cache -q bash; fi
    exec bash "$0" "$@"
fi
# XIVLegacy server: one-time setup of a Linux machine (a small VPS is the target:
# 1 GB RAM, 1-2 x86-64 vCPUs). Run as root from an unpacked server bundle or a
# checkout of the repository:
#
#   sudo ./ops/linux/install.sh [--address xiv.example.com] [--world-name Fernehalwes]
#                               [--ssh-port 22] [--no-firewall] [--no-swap]
#
# What it does (safe to run again; it keeps an existing password and settings):
#   1. installs MariaDB and the few tools xiv.sh uses (apt, dnf, apk or pacman)
#   2. puts MariaDB on 127.0.0.1 only, with a small-memory config
#   3. creates the database and its user; the generated password goes into
#      /etc/xivlegacy/db.env (mode 0600, root only) and is never printed
#   4. creates the 'xivlegacy' service user and the folders
#   5. installs the services (systemd; OpenRC on Alpine and other non-systemd systems)
#   6. opens the game ports (and keeps SSH open) in ufw or firewalld when present
#   7. adds a 1 GB swap file when the machine has under 2 GB of RAM
#   8. installs the 'xiv' command (/usr/local/sbin/xiv)
#   9. when run from a server bundle, installs that bundle and starts the servers
#
# Layout afterwards:
#   /etc/xivlegacy/xiv.conf       address, world name, ports (edit, then 'xiv restart')
#   /etc/xivlegacy/db.env         the database URL with its password (0600)
#   /opt/xivlegacy/releases/<sha> unpacked bundles; /opt/xivlegacy/current -> the running one
#   /var/lib/xivlegacy            the servers' working folder (settings, data, bug reports)
#   /var/backups/xivlegacy        database dumps
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ADDRESS=""
WORLD_NAME="Fernehalwes"
SSH_PORT=""
FIREWALL=1
SWAP=1

while [ $# -gt 0 ]; do
    case "$1" in
        --address) ADDRESS="$2"; shift 2 ;;
        --world-name) WORLD_NAME="$2"; shift 2 ;;
        --ssh-port) SSH_PORT="$2"; shift 2 ;;
        --no-firewall) FIREWALL=0; shift ;;
        --no-swap) SWAP=0; shift ;;
        -h|--help) sed -n "7,35p" "$0"; exit 0 ;;
        *) echo "unknown option: $1 (see --help)" >&2; exit 2 ;;
    esac
done

say()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "run this as root (sudo $0)"
[ -f "$HERE/xiv.sh" ] && [ -f "$HERE/mariadb-small.cnf" ] || die "run install.sh from its own folder in a bundle or checkout (ops/linux)"
case "$(uname -m)" in
    x86_64|amd64) ;;
    *) warn "this machine is $(uname -m); the server bundles are built for x86_64 only" ;;
esac

ETC=/etc/xivlegacy
OPT=/opt/xivlegacy
VAR=/var/lib/xivlegacy
BACKUPS=/var/backups/xivlegacy
LOGDIR=/var/log/xivlegacy
SVC_USER=xivlegacy

# ---------------------------------------------------------------- package manager & init
if command -v apt-get >/dev/null 2>&1; then PM=apt
elif command -v dnf >/dev/null 2>&1; then PM=dnf
elif command -v apk >/dev/null 2>&1; then PM=apk
elif command -v pacman >/dev/null 2>&1; then PM=pacman
else die "no apt, dnf, apk or pacman found; install MariaDB by hand and see ops/linux/README.md"
fi

if [ -d /run/systemd/system ]; then INIT=systemd
elif command -v openrc-run >/dev/null 2>&1 || [ -x /sbin/openrc-run ]; then INIT=openrc
else die "neither systemd nor OpenRC is running here"
fi
say "package manager: $PM, init: $INIT"

# ---------------------------------------------------------------- 1. packages
say "installing MariaDB and tools"
case "$PM" in
    apt)
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -qq
        apt-get install -y -qq mariadb-server mariadb-client curl ca-certificates jq unzip gzip tar iproute2 procps util-linux >/dev/null
        ;;
    dnf)
        pkgs="mariadb-server mariadb jq unzip gzip tar iproute procps-ng util-linux"
        # Rocky/Alma ship curl-minimal, which conflicts with the 'curl' package.
        command -v curl >/dev/null 2>&1 || pkgs="$pkgs curl"
        # shellcheck disable=SC2086
        dnf install -y -q $pkgs
        ;;
    apk)
        apk add --no-cache -q bash mariadb mariadb-client mariadb-openrc curl ca-certificates jq unzip gzip tar iproute2 procps util-linux shadow
        ;;
    pacman)
        pacman -Sy --noconfirm --needed --quiet mariadb curl jq unzip gzip tar iproute2 procps-ng util-linux >/dev/null
        ;;
esac

MARIADB="$(command -v mariadb || command -v mysql)" || die "MariaDB client not found after installing"

# ---------------------------------------------------------------- 2. MariaDB config + service
if [ -d /etc/mysql/mariadb.conf.d ]; then CNF_DIR=/etc/mysql/mariadb.conf.d
elif [ -d /etc/my.cnf.d ]; then CNF_DIR=/etc/my.cnf.d
else
    CNF_DIR=/etc/my.cnf.d
    mkdir -p "$CNF_DIR"
    grep -qs '!includedir /etc/my.cnf.d' /etc/my.cnf || printf '\n!includedir /etc/my.cnf.d\n' >> /etc/my.cnf
fi
# 'zz-' so it's read last: Alpine's own mariadb-server.cnf turns TCP off (skip-networking).
CNF_CHANGED=1
if cmp -s "$HERE/mariadb-small.cnf" "$CNF_DIR/zz-xivlegacy.cnf" 2>/dev/null; then CNF_CHANGED=0; fi
rm -f "$CNF_DIR/90-xivlegacy.cnf"
install -m 0644 "$HERE/mariadb-small.cnf" "$CNF_DIR/zz-xivlegacy.cnf"
say "MariaDB config: $CNF_DIR/zz-xivlegacy.cnf (127.0.0.1 only, small buffers)"

# A fresh data folder needs initializing on Alpine and Arch (Debian and RHEL do it themselves).
MYSQL_DATADIR=/var/lib/mysql
if [ ! -d "$MYSQL_DATADIR/mysql" ]; then
    case "$PM" in
        apk)
            if [ -x /etc/init.d/mariadb ]; then /etc/init.d/mariadb setup >/dev/null; fi ;;
        pacman)
            mariadb-install-db --user=mysql --basedir=/usr --datadir="$MYSQL_DATADIR" >/dev/null ;;
    esac
fi

# Restart MariaDB only for a new config, and then with the game servers stopped
# (on a second run they may be up).
XIV_WAS_UP=0
if [ "$CNF_CHANGED" = 1 ] && [ -x /usr/local/sbin/xiv ] && [ -L "$OPT/current" ]; then
    if [ "$(/usr/local/sbin/xiv status 2>/dev/null | sed -n 's/^Ports listening: \([0-9]\).*/\1/p')" != 0 ]; then
        XIV_WAS_UP=1
        say "stopping the game servers while MariaDB restarts"
        if [ "$INIT" = systemd ]; then systemctl stop xivlegacy.target; else for s in map world lobby web; do rc-service "xivlegacy-$s" stop >/dev/null 2>&1 || true; done; fi
    fi
fi
if [ "$INIT" = systemd ]; then
    systemctl enable -q mariadb
    if [ "$CNF_CHANGED" = 1 ]; then systemctl restart mariadb; else systemctl start mariadb; fi
else
    rc-update add mariadb default >/dev/null 2>&1 || true
    if rc-service mariadb status >/dev/null 2>&1; then
        [ "$CNF_CHANGED" = 0 ] || rc-service mariadb restart >/dev/null
    elif ! rc-service mariadb start >/dev/null 2>&1; then
        # A first start can outlast OpenRC's wait on a slow disk; give it one more go.
        sleep 10
        rc-service mariadb zap >/dev/null 2>&1 || true
        pkill -x mariadbd 2>/dev/null && sleep 5 || true
        rc-service mariadb start >/dev/null
    fi
fi

for _ in $(seq 120); do
    "$MARIADB" -N -B -e 'SELECT 1' >/dev/null 2>&1 && break
    sleep 1
done
"$MARIADB" -N -B -e 'SELECT 1' >/dev/null 2>&1 \
    || die "can't reach MariaDB as root over its socket (root must use unix_socket login, the default on current distributions)"
say "MariaDB $("$MARIADB" -N -B -e 'SELECT VERSION()') is running"

# ---------------------------------------------------------------- 3. database + user
mkdir -p "$ETC"
chmod 0755 "$ETC"
DB_NAME=xivlegacy
DB_USER=xivlegacy
if [ -f "$ETC/db.env" ]; then
    # Keep the existing password.
    DB_PASS="$(sed -n 's#^XIVLEGACY_DB_URL=mysql://[^:]*:\([^@]*\)@.*#\1#p' "$ETC/db.env")"
fi
if [ -z "${DB_PASS:-}" ]; then
    DB_PASS="$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32 || true)"
    [ "${#DB_PASS}" -eq 32 ] || die "couldn't generate a password"
fi
# The SQL goes in on stdin so the password never shows in a process list.
"$MARIADB" <<SQL
CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$DB_USER'@'127.0.0.1' IDENTIFIED BY '$DB_PASS';
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
ALTER USER '$DB_USER'@'127.0.0.1' IDENTIFIED BY '$DB_PASS';
ALTER USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'127.0.0.1';
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
SQL
(
    umask 077
    printf 'XIVLEGACY_DB_URL=mysql://%s:%s@127.0.0.1:3306/%s\n' "$DB_USER" "$DB_PASS" "$DB_NAME" > "$ETC/db.env.tmp"
)
mv -f "$ETC/db.env.tmp" "$ETC/db.env"
chown root:root "$ETC/db.env"
chmod 0600 "$ETC/db.env"
unset DB_PASS
say "database '$DB_NAME' and user '$DB_USER' ready; password in $ETC/db.env (root only)"

# ---------------------------------------------------------------- 4. service user + folders
if ! id "$SVC_USER" >/dev/null 2>&1; then
    NOLOGIN="$(command -v nologin || echo /sbin/nologin)"
    if command -v useradd >/dev/null 2>&1; then
        useradd --system --user-group --home-dir "$VAR" --no-create-home --shell "$NOLOGIN" "$SVC_USER"
    else
        addgroup -S "$SVC_USER"
        adduser -S -D -H -h "$VAR" -s "$NOLOGIN" -G "$SVC_USER" "$SVC_USER"
    fi
    say "created the system user '$SVC_USER'"
fi
mkdir -p "$OPT/releases" "$VAR/settings" "$VAR/data" "$BACKUPS" "$LOGDIR"
chown -R "$SVC_USER:$SVC_USER" "$VAR" "$LOGDIR"
chmod 0750 "$VAR" "$BACKUPS"

# ---------------------------------------------------------------- xiv.conf
if [ -z "$ADDRESS" ] && [ -f "$ETC/xiv.conf" ]; then
    ADDRESS="$(sed -n 's/^PUBLIC_ADDRESS="\{0,1\}\([^"]*\)"\{0,1\}$/\1/p' "$ETC/xiv.conf")"
fi
if [ -z "$ADDRESS" ]; then
    # The address this machine uses to reach the internet; on a VPS that's its public IP.
    ADDRESS="$(ip -4 route get 1.1.1.1 2>/dev/null | sed -n 's/.* src \([0-9.]*\).*/\1/p' | head -n1)"
    [ -n "$ADDRESS" ] || ADDRESS=127.0.0.1
    warn "no --address given; using $ADDRESS (change PUBLIC_ADDRESS in $ETC/xiv.conf if players should use a host name)"
fi
if [ ! -f "$ETC/xiv.conf" ]; then
    cat > "$ETC/xiv.conf" <<CONF
# XIVLegacy server settings for this machine. After editing: xiv restart
#
# The address players' launchers connect to (a host name or this server's public IP).
PUBLIC_ADDRESS="$ADDRESS"
# Shown in the launcher's world list.
WORLD_NAME="$WORLD_NAME"
# The launcher always uses these three ports; the map server stays on 127.0.0.1.
WEB_PORT=54993
LOBBY_PORT=54994
WORLD_PORT=54992
MAP_PORT=1989
# Where the public servers listen (0.0.0.0 = every address).
BIND_IP=0.0.0.0
# Server log detail: info, or debug for our crates when chasing a problem.
RUST_LOG="info,common=info,lobby_server=info,world_server=info,map_server=info"
# Where 'xiv deploy <ref>' gets builds, and the branch it deploys by default.
GITHUB_REPO="tagban/xivlegacy-server"
DEFAULT_REF="develop"
# Backups older than this many days are removed (the newest 7 are always kept).
KEEP_BACKUP_DAYS=14
CONF
    say "wrote $ETC/xiv.conf (players connect to $ADDRESS)"
else
    say "keeping the existing $ETC/xiv.conf"
fi
# shellcheck disable=SC1091
. "$ETC/xiv.conf"

# ---------------------------------------------------------------- 5. services
SERVICES="web lobby world map"
if [ "$INIT" = systemd ]; then
    MARIA_UNIT=mariadb.service
    for s in $SERVICES; do
        case "$s" in
            web)
                after="network-online.target $MARIA_UNIT"
                wants="network-online.target $MARIA_UNIT"
                # The web server sets the database up (schema, game data,
                # migrations) before it listens; the others wait for it.
                post="ExecStartPost=/usr/local/sbin/xiv _wait-web"
                timeout=900 ;;
            *)
                after="xivlegacy-web.service $MARIA_UNIT"
                wants="xivlegacy-web.service"
                post=""
                timeout=120 ;;
        esac
        cat > "/etc/systemd/system/xivlegacy-$s.service" <<UNIT
# Written by ops/linux/install.sh; run it again to rewrite.
[Unit]
Description=XIVLegacy $s server
After=$after
Wants=$wants
PartOf=xivlegacy.target
# Up to 5 crashes an hour, then it stays down until 'xiv start'.
StartLimitIntervalSec=3600
StartLimitBurst=5

[Service]
Type=simple
User=$SVC_USER
Group=$SVC_USER
WorkingDirectory=$VAR
EnvironmentFile=$ETC/db.env
EnvironmentFile=-$VAR/runtime.env
Environment=XIVLEGACY_SETTINGS=$VAR/settings
ExecStart=$OPT/current/bin/$s-server --no-console
$post
TimeoutStartSec=$timeout
TimeoutStopSec=30
Restart=on-failure
RestartSec=5
StandardInput=null
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ProtectHome=true
ReadWritePaths=$VAR

[Install]
WantedBy=xivlegacy.target
UNIT
    done
    cat > /etc/systemd/system/xivlegacy.target <<UNIT
# Written by ops/linux/install.sh. 'xiv start' / 'xiv stop' drive this.
[Unit]
Description=XIVLegacy servers (web, lobby, world, map)
Wants=xivlegacy-web.service xivlegacy-lobby.service xivlegacy-world.service xivlegacy-map.service

[Install]
WantedBy=multi-user.target
UNIT
    systemctl daemon-reload
    systemctl enable -q xivlegacy.target
    for s in $SERVICES; do systemctl enable -q "xivlegacy-$s.service"; done
    say "systemd units: xivlegacy.target + xivlegacy-{web,lobby,world,map}.service"
else
    for s in $SERVICES; do
        case "$s" in
            web) need="need mariadb net"; post='start_post() { /usr/local/sbin/xiv _wait-web; }' ;;
            *)   need="need mariadb xivlegacy-web"; post="" ;;
        esac
        cat > "/etc/init.d/xivlegacy-$s" <<RC
#!/sbin/openrc-run
# Written by ops/linux/install.sh; run it again to rewrite.
description="XIVLegacy $s server"
supervisor=supervise-daemon
command="$OPT/current/bin/$s-server"
command_args="--no-console"
command_user="$SVC_USER:$SVC_USER"
directory="$VAR"
output_log="$LOGDIR/$s.log"
error_log="$LOGDIR/$s.log"
# Up to 5 crashes an hour.
respawn_delay=5
respawn_max=5
respawn_period=3600

depend() {
    $need
}

start_pre() {
    set -a
    . $ETC/db.env
    [ -f $VAR/runtime.env ] && . $VAR/runtime.env
    set +a
    export XIVLEGACY_SETTINGS=$VAR/settings
    checkpath -f -o $SVC_USER:$SVC_USER -m 0640 "$LOGDIR/$s.log"
}
$post
RC
        chmod 0755 "/etc/init.d/xivlegacy-$s"
        rc-update add "xivlegacy-$s" default >/dev/null
    done
    say "OpenRC services: xivlegacy-{web,lobby,world,map} (logs in $LOGDIR)"
fi

if [ "$XIV_WAS_UP" = 1 ]; then
    say "starting the game servers again"
    /usr/local/sbin/xiv start >/dev/null || warn "the game servers didn't come back; see: xiv logs"
fi

# ---------------------------------------------------------------- 6. firewall
if [ "$FIREWALL" = 1 ]; then
    if [ -z "$SSH_PORT" ]; then
        SSH_PORT="$(sshd -T 2>/dev/null | sed -n 's/^port //p' | head -n1 || true)"
        [ -n "$SSH_PORT" ] || SSH_PORT=22
    fi
    GAME_PORTS="$WEB_PORT $LOBBY_PORT $WORLD_PORT"
    if command -v ufw >/dev/null 2>&1; then
        ufw allow "$SSH_PORT/tcp" >/dev/null
        for p in $GAME_PORTS; do ufw allow "$p/tcp" >/dev/null; done
        if ufw status | grep -q '^Status: active'; then
            say "ufw: opened $SSH_PORT (SSH) and $GAME_PORTS"
        else
            say "ufw: rules added for $SSH_PORT (SSH) and $GAME_PORTS; ufw itself is off (turn it on with: ufw enable)"
        fi
    elif command -v firewall-cmd >/dev/null 2>&1 && firewall-cmd --state >/dev/null 2>&1; then
        firewall-cmd -q --permanent --add-port="$SSH_PORT/tcp"
        for p in $GAME_PORTS; do firewall-cmd -q --permanent --add-port="$p/tcp"; done
        firewall-cmd -q --reload
        say "firewalld: opened $SSH_PORT (SSH) and $GAME_PORTS"
    else
        say "no ufw or firewalld running; open TCP $GAME_PORTS in the VPS provider's firewall if it has one"
    fi
    # The map server ($MAP_PORT) and MariaDB (3306) listen on 127.0.0.1 only; nothing to open.
fi

# ---------------------------------------------------------------- 7. swap
if [ "$SWAP" = 1 ]; then
    mem_kb="$(sed -n 's/^MemTotal: *\([0-9]*\).*/\1/p' /proc/meminfo)"
    swap_kb="$(sed -n 's/^SwapTotal: *\([0-9]*\).*/\1/p' /proc/meminfo)"
    if [ "${mem_kb:-0}" -lt 2000000 ] && [ "${swap_kb:-0}" -eq 0 ]; then
        if [ ! -f /swapfile ]; then
            fallocate -l 1G /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1M count=1024 status=none
            chmod 0600 /swapfile
            mkswap /swapfile >/dev/null
        fi
        if swapon /swapfile 2>/dev/null; then
            grep -qs '^/swapfile ' /etc/fstab || echo '/swapfile none swap defaults 0 0' >> /etc/fstab
            sysctl -q vm.swappiness=10 || true
            echo 'vm.swappiness=10' > /etc/sysctl.d/90-xivlegacy-swap.conf
            say "added a 1 GB swap file (/swapfile, swappiness 10)"
        else
            warn "couldn't turn on /swapfile (containers can't); left it off"
            rm -f /swapfile
        fi
    fi
fi

# ---------------------------------------------------------------- 8. the xiv command
mkdir -p /usr/local/sbin
install -m 0755 "$HERE/xiv.sh" /usr/local/sbin/xiv.new
mv -f /usr/local/sbin/xiv.new /usr/local/sbin/xiv
say "installed the 'xiv' command (/usr/local/sbin/xiv)"

# ---------------------------------------------------------------- 9. this bundle
BUNDLE="$(cd "$HERE/../.." && pwd)"
if [ -f "$BUNDLE/BUILD" ] && [ -x "$BUNDLE/bin/map-server" ]; then
    if [ -L "$OPT/current" ]; then
        say "a server is already installed ($(readlink "$OPT/current")); update it with: xiv deploy"
    else
        say "installing this bundle and starting the servers"
        /usr/local/sbin/xiv deploy --dir "$BUNDLE"
    fi
else
    say "next: xiv deploy develop   (or: xiv deploy --file xivlegacy-server-linux-x86_64-<sha>.tar.gz)"
fi

cat <<DONE

Done. Players connect to $PUBLIC_ADDRESS (launcher ports $WEB_PORT/$LOBBY_PORT/$WORLD_PORT).
  xiv status            what's running, players online
  xiv import <dump>     load a database dump (e.g. a backup from the NUC)
  xiv deploy develop    update to the newest build of a branch (needs a GitHub token; see README)
DONE
