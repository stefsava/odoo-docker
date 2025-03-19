#!/bin/bash

# This script installs Odoo Community Edition on Dokku
# Maintainer: Stefano Savanelli <stefano@savanelli.it>

VERSION=18.0

# Function: Exit with an error message
exit_abnormal() {
  echo "❌ Error: $1"
  exit 1
}

# Function: Generate a random secure password
generate_password() {
  openssl rand -base64 24 | tr -d "=+/[:space:]"
}

# Validate Dokku installation
if ! command -v dokku &> /dev/null; then
  exit_abnormal "Dokku is not installed. Please install Dokku first."
fi

# Parse command-line arguments
while getopts ":a:m:p:d:v:" options; do
  case "${options}" in
    a) APPNAME=${OPTARG} ;;
    m) MASTERPASSWORD=${OPTARG} ;;
    p) PGPASSWORD=${OPTARG} ;;
    d) PGNAME=${OPTARG} ;;
    v) VERSION=${OPTARG} ;;
    :) exit_abnormal "-${OPTARG} requires an argument." ;;
    *) exit_abnormal "Invalid argument." ;;
  esac
done

# Validate required parameters
if [[ -z "$APPNAME" ]]; then
  exit_abnormal "Missing -a APPNAME parameter!"
fi

# Set PGNAME to APPNAME if not provided
PGNAME=${PGNAME:-$APPNAME}

# Generate passwords if not provided
MASTERPASSWORD=${MASTERPASSWORD:-$(generate_password)}
PGPASSWORD=${PGPASSWORD:-$(generate_password)}

echo "🔹 Installing Odoo on Dokku..."
echo "➡ Odoo App Name: ${APPNAME}"
echo "➡ Odoo Version: ${VERSION}"
echo "➡ PostgreSQL Service Name: ${PGNAME}"
echo "➡ PostgreSQL Username: odoo"

# Check if the Dokku app already exists
if ! dokku apps:exists $APPNAME; then
  echo "✅ Creating Dokku app '$APPNAME'..."
  dokku apps:create $APPNAME
fi

# Check if the PostgreSQL database already exists
if ! dokku postgres:exists $PGNAME; then
  echo "✅ Creating PostgreSQL service '$PGNAME'..."
  dokku postgres:create $PGNAME
fi

# Link PostgreSQL database to the application (if not already linked)
if ! dokku postgres:linked $PGNAME $APPNAME; then
  echo "🔗 Linking PostgreSQL service '$PGNAME' to '$APPNAME'..."
  dokku postgres:link $PGNAME $APPNAME
fi

# Configure PostgreSQL user for Odoo
echo "🔹 Configuring PostgreSQL..."
echo "
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'odoo') THEN
    CREATE USER odoo WITH PASSWORD '$PGPASSWORD';
    ALTER USER odoo WITH CREATEDB;
  END IF;
END $$;
" | dokku postgres:connect $PGNAME

# Define storage paths
STORAGE_PATH="/var/lib/dokku/data/storage/$APPNAME"
mkdir -p $STORAGE_PATH/{filestore,sessions,addons,ssh,scripts}

# Mount storage volumes in Dokku (only if not already mounted)
if ! dokku storage:report $APPNAME | grep -q "/opt/odoo/additional_addons"; then
  dokku storage:mount $APPNAME $STORAGE_PATH/addons:/opt/odoo/additional_addons
  dokku storage:mount $APPNAME $STORAGE_PATH/filestore:/opt/odoo/data/filestore
  dokku storage:mount $APPNAME $STORAGE_PATH/sessions:/opt/odoo/data/sessions
  dokku storage:mount $APPNAME $STORAGE_PATH/scripts:/opt/scripts
  dokku storage:mount $APPNAME $STORAGE_PATH/ssh:/opt/odoo/ssh:ro
fi

# Configure Dokku proxy for Odoo
dokku proxy:ports-add $APPNAME http:80:8069
dokku proxy:ports-add $APPNAME http:8072:8072

# Set environment variables for Odoo
dokku config:set $APPNAME \
  ODOO_ADMIN_PASSWD=$MASTERPASSWORD \
  ODOO_DB_HOST=dokku-postgres-$PGNAME \
  ODOO_DB_USER=odoo \
  ODOO_DB_PASSWORD=$PGPASSWORD \
  ODOO_VERSION=$VERSION \
  DOKKU_DOCKERFILE_START_CMD="start"

# Deploy Odoo using the image
docker pull stefsava/odoo:$VERSION || exit_abnormal "Odoo Docker image not found!"
dokku git:from-image $APPNAME stefsava/odoo:$VERSION

# Enable HTTPS with Let's Encrypt
dokku letsencrypt $APPNAME

echo "✅ Odoo $VERSION has been successfully installed on Dokku!"
