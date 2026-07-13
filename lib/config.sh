# Configuration: defaults -> migrate.conf -> environment variables
load_config() {
    CONFIG_FILE="${MIGRASQL_CONFIG:-$ROOT_DIR/migrate.conf}"
    if [[ -f "$CONFIG_FILE" ]]; then
        # shellcheck source=/dev/null
        source "$CONFIG_FILE"
    fi

    DB_USER="${DB_USER:-root}"
    DB_NAME="${DB_NAME:-}"
    DB_HOST="${DB_HOST:-}"
    DB_PORT="${DB_PORT:-}"
    DB_CLIENT="${DB_CLIENT:-}"
    MIGRATIONS_DIR="${MIGRATIONS_DIR:-$ROOT_DIR/migrations}"

    if [[ -z "$DB_NAME" ]]; then
        log_error "DB_NAME is not set."
        log_error "Copy 'migrate.conf.example' to 'migrate.conf' and set DB_NAME."
        exit 1
    fi
}
