#!/bin/bash

# This script installs Odoo Community Edition on Dokku
# Maintainer: Stefano Savanelli <stefano@savanelli.it>

set -e  # Stop execution on any error

VERSION=18.0
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
LOG_DIR="/var/log/odoo_on_dokku"
VERBOSE=false

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Function: Exit with an error message and show log path
exit_abnormal() {
  echo "❌ Error: $1"
  echo "📄 Log file: $LOG_FILE"
  exit 1
}

# Function: Generate a random secure password (hidden from logs)
generate_password() {
  openssl rand -base64 24 | tr -d "=+/[:space:]"
}

# Enable verbose mode
enable_verbose() {
  VERBOSE=true
  set -x  # Show executed commands
}

# Parse command-line arguments
while getopts ":v" options; do
  case "${options}" in
    v) enable_verbose ;;
    :) exit_abnormal "-${OPTARG} requires an argument." ;;
    *) exit_abnormal "Invalid argument." ;;
  esac
done

shift $((OPTIND - 1))

# Set APPNAME as first argument if provided
if [[ -n "$1" ]]; then
  APPNAME="$1"
else
  exit_abnormal "Missing APPNAME! Pass the app name as the first argument."
fi

# PostgreSQL database name (same as APPNAME)
PGNAME="$APPNAME"

# Set log file path
LOG_FILE="$LOG_DIR/$APPNAME-$TIMESTAMP.log"

# Redirect all output and errors to log file and console
exec > >(tee -a "$LOG_FILE") 2>&1

echo "🔹 Installing Odoo on Dokku..."
echo "➡ Odoo App Name: ${APPNAME}"
echo "➡ Odoo Version: ${VERSION}"

# Pull Odoo image (first step)
echo "🔹 Checking Odoo image availability..."
if ! docker pull stefsava/odoo:"$VERSION" > /dev/null 2>&1; then
  exit_abnormal "Odoo Docker image not found!"
fi

# Stop if app, DB or storage already exist
if dokku apps:exists "$APPNAME"; then
  exit_abnormal "Dokku app '$APPNAME' already exists!"
fi

if dokku postgres:exists "$PGNAME"; then
  exit_abnormal "PostgreSQL service '$PGNAME' already exists!"
fi

STORAGE_PATH="/var/lib/dokku/data/storage/$APPNAME"
if [[ -d "$STORAGE_PATH" ]]; then
  exit_abnormal "Storage path '$STORAGE_PATH' already exists!"
fi

# Generate passwords (but do not log them)
MASTERPASSWORD=$(generate_password)
PGPASSWORD=$(generate_password)

echo "➡ PostgreSQL Service Name: ${PGNAME}"
echo "➡ PostgreSQL Username: odoo"
echo "🔹 Secure credentials generated (hidden from logs)"

# Create Dokku app
echo "✅ Creating Dokku app '$APPNAME'..."
dokku apps:create "$APPNAME"

# Create PostgreSQL service
echo "✅ Creating PostgreSQL service '$PGNAME'..."
dokku postgres:create "$PGNAME"

# Link PostgreSQL database to the application
echo "🔗 Linking PostgreSQL service '$PGNAME' to '$APPNAME'..."
dokku postgres:link "$PGNAME" "$APPNAME"

# Configure PostgreSQL user for Odoo (hidden output)
echo "🔹 Configuring PostgreSQL (password hidden)..."
echo "
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'odoo') THEN
    CREATE USER odoo WITH PASSWORD '$PGPASSWORD';
    ALTER USER odoo WITH CREATEDB;
  END IF;
END \$\$
" | dokku postgres:connect "$PGNAME" > /dev/null 2>&1

# Define storage paths
mkdir -p "$STORAGE_PATH"/{filestore,sessions,addons,ssh,scripts}
dokku storage:ensure-directory

# Mount storage volumes in Dokku
echo "🔹 Mounting storage volumes..."
dokku storage:mount "$APPNAME" "$STORAGE_PATH/addons:/opt/odoo/additional_addons"
dokku storage:mount "$APPNAME" "$STORAGE_PATH/filestore:/opt/odoo/data/filestore"
dokku storage:mount "$APPNAME" "$STORAGE_PATH/sessions:/opt/odoo/data/sessions"
dokku storage:mount "$APPNAME" "$STORAGE_PATH/scripts:/opt/scripts"
dokku storage:mount "$APPNAME" "$STORAGE_PATH/ssh:/opt/odoo/ssh:ro"

# Configure Dokku proxy for Odoo
echo "🔹 Configuring proxy..."
dokku ports:set "$APPNAME" http:80:8069

# Setup Nginx configuration for longpolling
echo "🔹 Configuring Nginx for longpolling..."
NGINX_CONF_DIR="/home/dokku/$APPNAME/nginx.conf.d"
mkdir -p "$NGINX_CONF_DIR"

cat <<EOF > "$NGINX_CONF_DIR/longpolling.conf"
location /longpolling {
    proxy_pass http://{{ .APP }}-8072;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_http_version 1.1;
    proxy_read_timeout 86400;
}
EOF

# Restart Nginx to apply changes
dokku proxy:build-config "$APPNAME"

# Set environment variables for Odoo (passwords hidden)
echo "🔹 Setting environment variables..."
dokku config:set "$APPNAME" \
  ODOO_ADMIN_PASSWD="$MASTERPASSWORD" \
  ODOO_DB_HOST="dokku-postgres-$PGNAME" \
  ODOO_DB_USER="odoo" \
  ODOO_DB_PASSWORD="$PGPASSWORD" \
  ODOO_VERSION="$VERSION" \
  DOKKU_DOCKERFILE_START_CMD="start" > /dev/null

# Deploy Odoo using the image
echo "🔹 Deploying Odoo..."
dokku git:from-image "$APPNAME" stefsava/odoo:"$VERSION"

# Enable HTTPS with Let's Encrypt
echo "🔹 Enabling Let's Encrypt..."
dokku letsencrypt "$APPNAME"

echo "✅ Odoo $VERSION has been successfully installed on Dokku!"
echo "📄 Log file: $LOG_FILE"
