#!/usr/bin/env bash
# ==============================================================================
# Script: provision-db.sh
# Purpose: Automatically creates an isolated user and database in PostgreSQL 18
# Usage: ./provision-db.sh <app_name>
# Run from: Janus host machine (or over SSH)
# ==============================================================================

set -euo pipefail

APP_NAME="${1:-}"

if [ -z "${APP_NAME}" ]; then
  echo "❌ Error: Missing app name."
  echo "Usage: ./provision-db.sh <app_name>"
  echo "Example: ./provision-db.sh smart-receipts"
  exit 1
fi

# Sanitize names (replace hyphens with underscores for PostgreSQL identifiers)
DB_USER=$(echo "${APP_NAME}_user" | tr '-' '_')
DB_NAME=$(echo "${APP_NAME}_db" | tr '-' '_')

echo "🔍 Locating active PostgreSQL 18 container..."
CONTAINER_NAME=$(docker ps --filter "ancestor=postgres:18-alpine" --format "{{.Names}}" | head -n 1)

if [ -z "${CONTAINER_NAME}" ]; then
  # Fallback to searching by standard image or coolify pattern
  CONTAINER_NAME=$(docker ps --filter "name=postgres" --format "{{.Names}}" | grep -v "coolify-db" | head -n 1 || true)
fi

if [ -z "${CONTAINER_NAME}" ]; then
  echo "❌ Error: Could not locate active application PostgreSQL container."
  echo "Please check 'docker ps' manually."
  exit 1
fi

echo "✅ Found PostgreSQL container: ${CONTAINER_NAME}"

# Generate cryptographically secure 24-character password
PASSWORD=$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 24)

echo "⏳ Provisioning user '${DB_USER}' and database '${DB_NAME}'..."

docker exec -i "${CONTAINER_NAME}" psql -U postgres << EOF
CREATE USER ${DB_USER} WITH ENCRYPTED PASSWORD '${PASSWORD}';
CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};
GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};
\c ${DB_NAME}
GRANT ALL ON SCHEMA public TO ${DB_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO ${DB_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO ${DB_USER};
EOF

echo ""
echo "=============================================================================="
echo "🎉 DATABASE PROVISIONED SUCCESSFULLY FOR: ${APP_NAME}"
echo "=============================================================================="
echo "Database Name: ${DB_NAME}"
echo "User:          ${DB_USER}"
echo "Password:      ${PASSWORD}"
echo ""
echo "Paste this connection string into your Coolify Environment Variables:"
echo ""
echo "DATABASE_URL=postgresql://${DB_USER}:${PASSWORD}@${CONTAINER_NAME}:5432/${DB_NAME}"
echo ""
echo "For Python AsyncPG (SQLAlchemy):"
echo "DATABASE_URL=postgresql+asyncpg://${DB_USER}:${PASSWORD}@${CONTAINER_NAME}:5432/${DB_NAME}"
echo "=============================================================================="
