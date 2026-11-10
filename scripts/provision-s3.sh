#!/usr/bin/env bash
# ==============================================================================
# Script: provision-s3.sh
# Purpose: Automatically creates an isolated MinIO bucket, scoped IAM policy,
#          and dedicated user credentials on Project Janus.
# Usage: ./provision-s3.sh <app_name> [bucket_name] [--public|--private]
# Run from: Janus host machine (or over SSH)
# ==============================================================================

set -euo pipefail

APP_NAME="${1:-}"
BUCKET_NAME="${2:-}"
ACCESS_TYPE="${3:---public}"

if [ -z "${APP_NAME}" ]; then
  echo "❌ Error: Missing app name."
  echo "Usage: ./provision-s3.sh <app_name> [bucket_name] [--public|--private]"
  echo "Example: ./provision-s3.sh nook"
  echo "Example: ./provision-s3.sh smart-receipts receipts-media --private"
  exit 1
fi

# Handle optional arguments
if [ -z "${BUCKET_NAME}" ] || [ "${BUCKET_NAME}" = "--public" ] || [ "${BUCKET_NAME}" = "--private" ]; then
  if [ "${BUCKET_NAME}" = "--public" ] || [ "${BUCKET_NAME}" = "--private" ]; then
    ACCESS_TYPE="${BUCKET_NAME}"
  fi
  BUCKET_NAME="${APP_NAME}-media"
fi

# Sanitize names (lowercase, hyphens instead of underscores)
PROJECT_NAME=$(echo "${APP_NAME}" | tr '_' '-' | tr '[:upper:]' '[:lower:]')
BUCKET_NAME=$(echo "${BUCKET_NAME}" | tr '_' '-' | tr '[:upper:]' '[:lower:]')
USER_NAME="${PROJECT_NAME}-user"
USER_SECRET=$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 24)
POLICY_NAME="${PROJECT_NAME}-policy"

echo "🔍 Locating active MinIO container..."
CONTAINER=$(docker ps --filter "name=minio" --format "{{.Names}}" | head -n 1)

if [ -z "${CONTAINER}" ]; then
  echo "❌ Error: Could not locate active MinIO container on Janus."
  exit 1
fi

echo "✅ Found MinIO container: ${CONTAINER}"

# Ensure 'mc' alias 'janus' is configured properly without carriage returns
if ! mc alias list janus >/dev/null 2>&1; then
  echo "⚙️ Initializing 'mc' alias for local MinIO..."
  MINIO_USER=$(docker exec "${CONTAINER}" env | grep '^MINIO_ROOT_USER=' | cut -d= -f2- | tr -d '\r\n')
  MINIO_PASS=$(docker exec "${CONTAINER}" env | grep '^MINIO_ROOT_PASSWORD=' | cut -d= -f2- | tr -d '\r\n')

  if [ -z "${MINIO_USER}" ] || [ -z "${MINIO_PASS}" ]; then
    echo "❌ Error: Could not extract MINIO_ROOT_USER / MINIO_ROOT_PASSWORD from container."
    exit 1
  fi

  mc alias set janus http://127.0.0.1:9000 "${MINIO_USER}" "${MINIO_PASS}" >/dev/null
fi

echo "⏳ Ensuring bucket '${BUCKET_NAME}' exists..."
mc mb --ignore-existing "janus/${BUCKET_NAME}" >/dev/null 2>&1 || true

echo "⏳ Registering scoped IAM policy '${POLICY_NAME}'..."
cat << EOF > "/tmp/${PROJECT_NAME}-policy.json"
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowListBucket",
      "Effect": "Allow",
      "Action": ["s3:ListBucket", "s3:GetBucketLocation"],
      "Resource": ["arn:aws:s3:::${BUCKET_NAME}"]
    },
    {
      "Sid": "AllowAllObjectActionsInsideBucket",
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
      "Resource": ["arn:aws:s3:::${BUCKET_NAME}/*"]
    }
  ]
}
EOF

mc admin policy create janus "${POLICY_NAME}" "/tmp/${PROJECT_NAME}-policy.json" >/dev/null 2>&1 || \
mc admin policy update janus "${POLICY_NAME}" "/tmp/${PROJECT_NAME}-policy.json" >/dev/null 2>&1 || true
rm -f "/tmp/${PROJECT_NAME}-policy.json"

echo "⏳ Creating user '${USER_NAME}' and attaching policy..."
mc admin user add janus "${USER_NAME}" "${USER_SECRET}" >/dev/null
mc admin policy attach janus "${POLICY_NAME}" --user "${USER_NAME}" >/dev/null

if [ "${ACCESS_TYPE}" != "--private" ]; then
  echo "🔓 Setting public download access on '${BUCKET_NAME}' for web PWA assets..."
  mc anonymous set download "janus/${BUCKET_NAME}" >/dev/null
fi

# Detect domain from MinIO config or default
DOMAIN=$(docker exec "${CONTAINER}" env | grep '^MINIO_SERVER_URL=' | cut -d= -f2- | tr -d '\r\n' || true)
if [ -z "${DOMAIN}" ]; then
  DOMAIN="https://s3.janus-lab.duckdns.org"
fi

echo ""
echo "=============================================================================="
echo "🎉 MINIO S3 PROVISIONED SUCCESSFULLY FOR: ${APP_NAME}"
echo "=============================================================================="
echo "Bucket Name:       ${BUCKET_NAME}"
echo "Access Key / User: ${USER_NAME}"
echo "Secret Key:        ${USER_SECRET}"
echo "Access Policy:     ${ACCESS_TYPE}"
echo ""
echo "Paste these connection strings into your Coolify Environment Variables:"
echo ""
echo "S3_ENDPOINT=http://minio:9000"
echo "S3_PUBLIC_ENDPOINT=${DOMAIN}"
echo "S3_BUCKET=${BUCKET_NAME}"
echo "S3_ACCESS_KEY=${USER_NAME}"
echo "S3_SECRET_KEY=${USER_SECRET}"
echo "S3_REGION=us-east-1"
echo "S3_FORCE_PATH_STYLE=true"
echo "=============================================================================="
