#!/bin/bash

# Configuration
VERSION="18.0"
IMAGE="odoo:$VERSION"
DOCKER_HUB_API="https://hub.docker.com/v2/repositories/library/odoo/tags/$VERSION"
DIGEST_FILE="$HOME/.odoo_docker_version"
NOTIFY_EMAIL="tuo@email.com"
SLACK_WEBHOOK_URL="https://hooks.slack.com/services/your/slack/webhook"

# Function: Get the latest digest from Docker Hub
get_remote_digest() {
  curl -s "$DOCKER_HUB_API" | jq -r '.digest'
}

# Function: Get the current local digest
get_local_digest() {
  docker inspect --format='{{index .RepoDigests 0}}' $IMAGE 2>/dev/null | awk -F'@' '{print $2}'
}

# Function: Send email notification
send_email() {
  local message="$1"
  echo -e "Subject: Odoo Docker Update Alert\n\n$message" | sendmail "$NOTIFY_EMAIL"
}

# Function: Send Slack notification
send_slack() {
  local message="$1"
  curl -X POST -H 'Content-type: application/json' --data "{\"text\":\"$message\"}" "$SLACK_WEBHOOK_URL"
}

# Get local and remote digests
REMOTE_DIGEST=$(get_remote_digest)
LOCAL_DIGEST=$(get_local_digest)

# Load the last known digest (if exists)
LAST_KNOWN_DIGEST=""
if [[ -f "$DIGEST_FILE" ]]; then
  LAST_KNOWN_DIGEST=$(cat "$DIGEST_FILE")
fi

# Compare digests to detect updates
if [[ "$REMOTE_DIGEST" != "$LOCAL_DIGEST" && "$REMOTE_DIGEST" != "$LAST_KNOWN_DIGEST" ]]; then
  echo "🚀 A new Odoo $VERSION image is available!"

  # Save the new digest
  echo "$REMOTE_DIGEST" > "$DIGEST_FILE"

  # Create a message
  MESSAGE="🚀 Odoo $VERSION has been updated on Docker Hub! \nNew Digest: $REMOTE_DIGEST"

  # Send notifications
  send_email "$MESSAGE"
  send_slack "$MESSAGE"

else
  echo "✅ Odoo $VERSION is up to date."
fi
