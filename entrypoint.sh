#!/bin/bash
set -e

# Run migrations
diesel_migrate() {
    /usr/local/cargo/bin/diesel --database-url "$1" migration --migration-dir "$2" run
}

diesel_migrate "$SYNC_SYNCSTORAGE_DATABASE_URL" syncstorage-mysql/migrations
diesel_migrate "$SYNC_TOKENSERVER_DATABASE_URL" tokenserver-db/migrations

# Parse token server database URL
parse_db_url() {
    local url=$1
    echo "$url" | awk -F[:/@] '{
        proto = $1
        user = $4
        pass = $5
        host = $6
        port = $7
        db = $8
        print proto "://" user ":" pass "@" host ":" port "/" db
    }'
}

IFS=':/@' read -r proto user pass host port db <<< "$(parse_db_url "$SYNC_TOKENSERVER_DATABASE_URL")"

# Create service and node if they don't exist
mysql -h "$host" -P "$port" -u "$user" -p"$pass" "$db" <<EOF
DELETE FROM services;
INSERT INTO services (id, service, pattern) VALUES (1, "sync-1.5", "{node}/1.5/{uid}");
INSERT INTO nodes (id, service, node, capacity, available, current_load, downed, backoff) VALUES
    (1, 1, "${SYNC_URL}", ${SYNC_CAPACITY}, ${SYNC_CAPACITY}, 0, 0, 0)
    ON DUPLICATE KEY UPDATE node = "${SYNC_URL}", capacity = ${SYNC_CAPACITY}, 
    available = (SELECT ${SYNC_CAPACITY} - current_load FROM (SELECT * FROM nodes) AS n2 WHERE id = 1);
EOF

# Write config file
cat > /config/local.toml <<EOF
master_secret = "${SYNC_MASTER_SECRET}"
human_logs = 1
host = "0.0.0.0"
port = 8000
syncstorage.database_url = "${SYNC_SYNCSTORAGE_DATABASE_URL}"
syncstorage.enable_quota = 0
syncstorage.enabled = true
tokenserver.database_url = "${SYNC_TOKENSERVER_DATABASE_URL}"
tokenserver.enabled = true
tokenserver.fxa_email_domain = "api.accounts.firefox.com"
tokenserver.fxa_metrics_hash_secret = "${METRICS_HASH_SECRET}"
tokenserver.fxa_oauth_server_url = "https://oauth.accounts.firefox.com"
tokenserver.fxa_browserid_audience = "https://token.services.mozilla.com"
tokenserver.fxa_browserid_issuer = "https://api.accounts.firefox.com"
tokenserver.fxa_browserid_server_url = "https://verifier.accounts.firefox.com/v2"
EOF

# Run server
source /app/venv/bin/activate
RUST_LOG=${LOGLEVEL:-warn} /usr/local/cargo/bin/syncserver --config /config/local.toml
