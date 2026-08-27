#!/usr/bin/env bash
# migrasql — raw-SQL migration manager for MariaDB/MySQL
set -euo pipefail

SOURCE="${BASH_SOURCE[0]}"
while [[ -L "$SOURCE" ]]; do SOURCE="$(readlink "$SOURCE")"; done
ROOT_DIR="$(cd "$(dirname "$SOURCE")/.." && pwd)"

source "$ROOT_DIR/lib/log.sh"
source "$ROOT_DIR/lib/config.sh"
source "$ROOT_DIR/lib/client.sh"
source "$ROOT_DIR/lib/db.sh"
source "$ROOT_DIR/lib/commands.sh"

ERR_LOG="$(mktemp)"
cleanup() {
    [[ -n "${TMP_CNF:-}" && -f "$TMP_CNF" ]] && rm -f "$TMP_CNF"
    [[ -f "$ERR_LOG" ]] && rm -f "$ERR_LOG"
}
trap cleanup EXIT

load_config
init_conn_args

COMMAND="${1:-up}"

case "$COMMAND" in
    help|-h|--help) cmd_help; exit 0 ;;
    new) shift; cmd_new "$@"; exit 0 ;;
esac

echo ""
echo "╔══════════════════════════════════════════════╗"
printf "║   migrasql — %-31s ║\n" "$DB_NAME"
echo "╚══════════════════════════════════════════════╝"
echo ""

DB_CLIENT="$(find_db_client || true)"
if [[ -z "$DB_CLIENT" ]]; then
    log_error "MariaDB/MySQL client not found."
    log_error "Install it with:  $(install_hint)"
    log_error "Or set DB_CLIENT=/path/to/binary in migrate.conf"
    exit 1
fi
log_info "Client: $DB_CLIENT"

if [[ ! -d "$MIGRATIONS_DIR" ]]; then
    log_error "Migrations directory not found: $MIGRATIONS_DIR"
    exit 1
fi

discover_auth
ensure_database
ensure_migrations_table

case "$COMMAND" in
    up)     cmd_up ;;
    status) cmd_status ;;
    *)      log_error "Unknown command: $COMMAND"; cmd_help; exit 1 ;;
esac

echo ""
