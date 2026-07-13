# Connection, authentication and control table
AUTH_MODE=""   # socket | sudo | cnf
TMP_CNF=""
CONN_ARGS=()

init_conn_args() {
    CONN_ARGS=()
    [[ -n "$DB_HOST" ]] && CONN_ARGS+=(-h "$DB_HOST")
    [[ -n "$DB_PORT" ]] && CONN_ARGS+=(-P "$DB_PORT" --protocol=TCP)
    return 0
}

run_db() {
    case "$AUTH_MODE" in
        sudo)
            sudo "$DB_CLIENT" -u "$DB_USER" "${CONN_ARGS[@]+"${CONN_ARGS[@]}"}" "$@"
            ;;
        cnf)
            # --defaults-extra-file must be the first argument
            "$DB_CLIENT" --defaults-extra-file="$TMP_CNF" "${CONN_ARGS[@]+"${CONN_ARGS[@]}"}" "$@"
            ;;
        *)
            "$DB_CLIENT" -u "$DB_USER" "${CONN_ARGS[@]+"${CONN_ARGS[@]}"}" "$@"
            ;;
    esac
}

try_connect() { run_db -e "SELECT 1;" &>/dev/null; }

discover_auth() {
    log_info "Detecting authentication method..."

    AUTH_MODE="socket"
    if try_connect; then
        log_ok "Direct connection without password."
        return 0
    fi

    if command -v sudo &>/dev/null && [[ -z "$DB_HOST" ]]; then
        AUTH_MODE="sudo"
        if try_connect; then
            log_ok "Authenticated via sudo (unix_socket plugin)."
            return 0
        fi
    fi

    log_warn "Could not connect automatically."
    echo -n "  → Password for user '$DB_USER': "
    read -rs DB_PASSWORD
    echo
    TMP_CNF="$(mktemp)"
    chmod 600 "$TMP_CNF"
    printf '[client]\nuser=%s\npassword=%s\n' "$DB_USER" "$DB_PASSWORD" > "$TMP_CNF"
    unset DB_PASSWORD
    AUTH_MODE="cnf"
    if try_connect; then
        log_ok "Password authentication confirmed."
        return 0
    fi

    log_error "Could not connect to the database."
    log_error "Check that the service is running:  $(service_hint)"
    exit 1
}

ensure_database() {
    run_db -e "CREATE DATABASE IF NOT EXISTS \`$DB_NAME\`
               CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
}

ensure_migrations_table() {
    run_db "$DB_NAME" -e "
        CREATE TABLE IF NOT EXISTS schema_migrations (
            id             INT AUTO_INCREMENT PRIMARY KEY,
            migration_name VARCHAR(255) NOT NULL UNIQUE,
            checksum       CHAR(64) NULL,
            applied_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
    "
}

file_checksum() { sha256sum "$1" | awk '{print $1}'; }

validate_name() { [[ "$1" =~ ^[A-Za-z0-9._-]+$ ]]; }

list_sql_files() {
    find "$MIGRATIONS_DIR" -maxdepth 1 -name "*.sql" -type f | sort
}

list_applied() {
    run_db -N -s -e "SELECT migration_name FROM \`$DB_NAME\`.schema_migrations;"
}

applied_checksum_of() {
    run_db -N -s -e "SELECT COALESCE(checksum,'') FROM \`$DB_NAME\`.schema_migrations
                     WHERE migration_name='$1' LIMIT 1;"
}

record_migration() {
    run_db -e "INSERT INTO \`$DB_NAME\`.schema_migrations (migration_name, checksum)
               VALUES ('$1', '$2');"
}
