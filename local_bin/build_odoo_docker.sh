#!/bin/bash

# This script builds the Odoo Docker image from the current directory
# or clones the repository if not already inside it.
#
# Usage:
#   ./local_bin/build_odoo_docker.sh [VERSION]
# Example:
#   ./local_bin/build_odoo_docker.sh 18.0

REPO_NAME="stefsava/odoo"
ODOO_BASE_IMAGE="odoo"
VERSION=${1:-18.0}  # Default to 18.0 if no version is provided
TIMESTAMP=$(date +%Y%m%d)

echo "🚀 Checking for updates to Odoo base image: $ODOO_BASE_IMAGE:$VERSION..."

# Pull the latest Odoo base image to ensure we are using the latest version
docker pull $ODOO_BASE_IMAGE:$VERSION

if [[ $? -ne 0 ]]; then
  echo "❌ Error: Unable to pull the Odoo base image!"
  exit 1
fi

# Check if we are already inside the Odoo project
if [[ -f "Dockerfile" && -d ".git" ]]; then
  echo "✅ Inside an existing Odoo project, building from local source."
else
  echo "🔍 Not inside an Odoo project. Cloning the repository..."

  if [[ -d "odoo-docker" ]]; then
    echo "⚠️ Warning: odoo-docker directory already exists. Using existing clone."
  else
    echo "🔄 Cloning repository..."
    git clone -b "$VERSION" --depth 1 https://github.com/stefsava/odoo-docker.git
  fi

  cd odoo-docker || exit
fi

# Build the Docker image using the latest Odoo base image
echo "🔨 Building Odoo Docker image..."
docker build --no-cache --pull -t $REPO_NAME:$VERSION .

if [[ $? -ne 0 ]]; then
  echo "❌ Error: Docker build failed!"
  exit 1
fi

# Tagging the image with timestamp
docker tag $REPO_NAME:$VERSION $REPO_NAME:$VERSION-$TIMESTAMP

# Verify the tags before pushing
docker images | grep "$REPO_NAME"

# Push to Docker Hub
echo "📤 Pushing images to Docker Hub..."
docker push $REPO_NAME:$VERSION
docker push $REPO_NAME:$VERSION-$TIMESTAMP

echo "✅ Docker image built and published successfully: $REPO_NAME:$VERSION"
echo "🕒 Version with timestamp: $REPO_NAME:$VERSION-$TIMESTAMP"

echo "🚀 Done."
