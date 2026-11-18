#!/usr/bin/env bash
# smoke-local.sh — CI/dev fail-fast boot check.
#
# Builds the workspace, then boots each garlemald service in `--smoke` mode
# against a throwaway MariaDB database and asserts it prints a matching SMOKE_OK
# line and exits 0. Any non-zero exit or missing marker fails the whole run.
#
# Usage:   scripts/smoke-local.sh
# Profile: PROFILE=debug scripts/smoke-local.sh   (default: release)
# Server:  XIVLEGACY_TEST_DB_URL=mysql://user:pass@host:port/ (default: the
#          XIV_DB_ADMIN_URL line of ~/.config/xivlegacy/db.env). The account
#          needs rights on databases named xivlegacy%.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

PROFILE="${PROFILE:-release}"
if [ "$PROFILE" = "release" ]; then
    BUILD_FLAGS=(--release)
    BIN_DIR="$REPO_ROOT/target/release"
else
    BUILD_FLAGS=()
    BIN_DIR="$REPO_ROOT/target/debug"
fi

echo "==> building workspace ($PROFILE)"
# Expand safely under `set -u`: on bash 3.2 (macOS default) a bare
# "${BUILD_FLAGS[@]}" errors as "unbound variable" when the array is empty
# (PROFILE=debug). The `+` alt-value form expands to nothing when unset/empty
# and to the quoted elements otherwise — portable across bash 3.2..5.x.
cargo build --workspace ${BUILD_FLAGS[@]+"${BUILD_FLAGS[@]}"}

DB_SERVER="${XIVLEGACY_TEST_DB_URL:-}"
if [ -z "$DB_SERVER" ] && [ -f "$HOME/.config/xivlegacy/db.env" ]; then
    DB_SERVER="$(sed -n 's/^XIV_DB_ADMIN_URL=//p' "$HOME/.config/xivlegacy/db.env")"
fi
DB_SERVER="${DB_SERVER:-mysql://xivlegacy@127.0.0.1:3306/}"
case "$DB_SERVER" in */) ;; *) DB_SERVER="$DB_SERVER/" ;; esac
SMOKE_DBS=()
cleanup() {
    # Drop the smoke databases when the mariadb client is around.
    command -v mariadb >/dev/null 2>&1 || return 0
    local auth host port user pass
    auth="${DB_SERVER#*://}"; auth="${auth%%/*}"
    host="${auth##*@}"; port="${host##*:}"; host="${host%%:*}"
    user="${auth%@*}"; pass="${user#*:}"; user="${user%%:*}"
    [ "$port" = "$host" ] && port=3306
    for db in ${SMOKE_DBS[@]+"${SMOKE_DBS[@]}"}; do
        MYSQL_PWD="$pass" mariadb -h "$host" -P "$port" -u "$user" \
            -e "DROP DATABASE IF EXISTS \`$db\`" >/dev/null 2>&1 || true
    done
}
trap cleanup EXIT

# Each service boots against its own fresh DB so a failure is isolated.
SERVICES=(web lobby world map)
FAILURES=0

for name in "${SERVICES[@]}"; do
    bin="$BIN_DIR/${name}-server"
    cfg="$REPO_ROOT/settings/default/${name}.toml"
    db_name="xivlegacy_smoke_${name}_$$"
    SMOKE_DBS+=("$db_name")
    db="${DB_SERVER}${db_name}"

    if [ ! -x "$bin" ]; then
        echo "SMOKE_FAIL ${name} driver: binary not found at ${bin}"
        FAILURES=$((FAILURES + 1))
        continue
    fi

    echo "==> smoke ${name} (${bin})"
    set +e
    output="$("$bin" --smoke --config "$cfg" --db-url "$db" 2>&1)"
    code=$?
    set -e
    echo "$output"

    if [ "$code" -eq 0 ] && printf '%s\n' "$output" | grep -q '^SMOKE_OK '; then
        echo "==> ${name} OK (exit 0, SMOKE_OK seen)"
    else
        echo "SMOKE_FAIL ${name} driver: exit=${code} (expected 0 + a SMOKE_OK line)"
        FAILURES=$((FAILURES + 1))
    fi
done

if [ "$FAILURES" -ne 0 ]; then
    echo "SMOKE_FAIL ${FAILURES} service(s) failed"
    exit 1
fi

echo "SMOKE_OK all services"
