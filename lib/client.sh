# mariadb/mysql client binary discovery
find_db_client() {
    if [[ -n "$DB_CLIENT" ]]; then
        [[ -x "$DB_CLIENT" ]] && { echo "$DB_CLIENT"; return 0; }
        log_error "DB_CLIENT is set but not executable: $DB_CLIENT"
        return 1
    fi

    local candidates=("mariadb" "mysql")
    local extra_paths=(
        "/usr/bin"
        "/usr/local/bin"
        "/usr/sbin"
        "/opt/mariadb/bin"
        "/opt/mysql/bin"
        "/usr/local/mariadb/bin"
        "/usr/local/mysql/bin"
        "/opt/lampp/bin"
        "/snap/bin"
        "$HOME/.local/bin"
    )

    local name dir
    for name in "${candidates[@]}"; do
        if command -v "$name" &>/dev/null; then
            command -v "$name"; return 0
        fi
        for dir in "${extra_paths[@]}"; do
            [[ -x "$dir/$name" ]] && { echo "$dir/$name"; return 0; }
        done
    done
    return 1
}

install_hint() {
    if command -v pacman   &>/dev/null; then echo "sudo pacman -S mariadb-clients"
    elif command -v apt    &>/dev/null; then echo "sudo apt install mariadb-client"
    elif command -v dnf    &>/dev/null; then echo "sudo dnf install mariadb"
    elif command -v zypper &>/dev/null; then echo "sudo zypper install mariadb-client"
    elif command -v apk    &>/dev/null; then echo "sudo apk add mariadb-client"
    else echo "install your distro's mariadb/mysql client and add it to PATH"
    fi
}

service_hint() {
    if command -v systemctl &>/dev/null; then
        echo "sudo systemctl status mariadb   (or mysql / mysqld)"
    elif command -v rc-service &>/dev/null; then
        echo "sudo rc-service mariadb status"
    elif [[ -x /opt/lampp/lampp ]]; then
        echo "sudo /opt/lampp/lampp startmysql"
    else
        echo "sudo service mysql status"
    fi
}
