# Commands: up | status | new | help
is_applied() {
    local target="$1" m
    for m in "${APPLIED[@]+"${APPLIED[@]}"}"; do
        [[ "$m" == "$target" ]] && return 0
    done
    return 1
}

cmd_status() {
    mapfile -t APPLIED < <(list_applied)
    mapfile -t SQL_FILES < <(list_sql_files)
    PENDING_COUNT=0

    if [[ ${#SQL_FILES[@]} -eq 0 ]]; then
        log_warn "No .sql files in: $MIGRATIONS_DIR"
        return 0
    fi

    local applied_count=0 modified_count=0
    echo ""
    echo "  ┌─ Migrations: ${#SQL_FILES[@]}"

    local file filename
    for file in "${SQL_FILES[@]}"; do
        filename="$(basename "$file" .sql)"
        if is_applied "$filename"; then
            local stored current
            stored="$(applied_checksum_of "$filename")"
            current="$(file_checksum "$file")"
            if [[ -n "$stored" && "$stored" != "$current" ]]; then
                echo -e "  │  ${RED}✖${NC} $filename (APPLIED BUT MODIFIED AFTERWARDS!)"
                modified_count=$((modified_count + 1))
            else
                echo -e "  │  ${GREEN}✔${NC} $filename (applied)"
            fi
            applied_count=$((applied_count + 1))
        else
            echo -e "  │  ${YELLOW}→${NC} $filename (pending)"
            PENDING_COUNT=$((PENDING_COUNT + 1))
        fi
    done

    echo "  └─ Applied: $applied_count | Pending: $PENDING_COUNT"
    if [[ $modified_count -gt 0 ]]; then
        echo ""
        log_warn "$modified_count migration(s) were edited after being applied."
        log_warn "Never edit an applied migration — create a new one instead."
    fi
    echo ""
}

cmd_up() {
    cmd_status
    if [[ "${PENDING_COUNT:-0}" -eq 0 ]]; then
        log_ok "Database is already up to date. Nothing to do."
        return 0
    fi

    local file filename sum done_count=0
    for file in "${SQL_FILES[@]}"; do
        filename="$(basename "$file" .sql)"

        if ! validate_name "$filename"; then
            log_error "Invalid name: '$filename' (use only letters, digits, '.', '_' and '-')"
            exit 1
        fi
        is_applied "$filename" && continue

        echo -n "  🚀 Applying '$filename'... "
        if run_db "$DB_NAME" < "$file" 2>"$ERR_LOG"; then
            sum="$(file_checksum "$file")"
            record_migration "$filename" "$sum"
            echo -e "${GREEN}OK${NC}"
            done_count=$((done_count + 1))
        else
            echo -e "${RED}FAILED${NC}"
            log_error "Error details:"
            cat "$ERR_LOG" >&2
            log_error "Note: for PROCEDURE/TRIGGER/FUNCTION use 'DELIMITER //' inside the file."
            exit 1
        fi
    done

    echo ""
    log_ok "$done_count migration(s) applied successfully."
}

cmd_new() {
    local name="${1:-}"
    if [[ -z "$name" ]]; then
        log_error "Usage: migrasql new <migration_name>"
        exit 1
    fi
    name="$(echo "$name" | tr ' ' '_' | tr -cd 'A-Za-z0-9._-')"
    local filename
    filename="$(date +%Y%m%d%H%M%S)_${name}.sql"
    mkdir -p "$MIGRATIONS_DIR"
    cat > "$MIGRATIONS_DIR/$filename" <<HEADER
-- Migration: $name
-- Created at: $(date '+%Y-%m-%d %H:%M:%S')
-- Author: $(whoami)

HEADER
    log_ok "Created: migrations/$filename"
}

cmd_help() {
    cat <<EOT

  migrasql — raw-SQL migration manager for MariaDB/MySQL

  Usage: migrasql [command]

  Commands:
    up          Apply pending migrations (default)
    status      Show the state of each migration
    new <name>  Create a timestamped migration file
    help        Show this help

  Configuration: migrate.conf (see migrate.conf.example) or environment
  variables: DB_USER, DB_NAME, DB_HOST, DB_PORT, DB_CLIENT, MIGRATIONS_DIR

EOT
}
