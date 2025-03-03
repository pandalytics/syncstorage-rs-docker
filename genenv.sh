#!/bin/bash

# Function to generate a random string
generate_random() {
    cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w ${1:-32} | head -n 1
}

# Generate .env file
cat > .env << EOF
##########################################
## Firefox SyncStorage RS Configuration ##
##########################################

DOMAIN= #fill in your domain here

# URL clients will use to connect to the sync server (ttps://hostname:8000)
# If you use a reverse proxy, that URL should be used here (https://sync.example.com)
SYNC_URL=https://\${DOMAIN}

# MySQL passwords (should be random)
MYSQL_ROOT_PASSWORD=$(generate_random 32)
MYSQL_PASSWORD=$(generate_random 32)

# Master sync key (must be 64 characters long)
SYNC_MASTER_SECRET=$(cat /dev/urandom | base32 | head -c64)

# Hashing secret (must be 64 characters long)
METRICS_HASH_SECRET=$(cat /dev/urandom | base32 | head -c64)
EOF

echo ".env file generated with secure random passwords."
