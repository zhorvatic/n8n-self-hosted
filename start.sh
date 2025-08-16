#!/bin/bash
set -e

# Usage: ./start.sh <environment>
ENVIRONMENT=${1:-prod}
APP_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$APP_DIR/.env"

echo "▶️ Deploying n8n (artifact-based) for environment: $ENVIRONMENT"
cd "$APP_DIR"

# Write version to static/version (from VERSION file if present, else 'unknown')
mkdir -p "$APP_DIR/static"
if [ -f "$APP_DIR/VERSION" ]; then
  cat "$APP_DIR/VERSION" > "$APP_DIR/static/version"
else
  echo "unknown" > "$APP_DIR/static/version"
fi
chmod a+r "$APP_DIR/static/version"

# --- Helpers ---
need() { command -v "$1" >/dev/null 2>&1 || { echo "❌ Missing dependency: $1" >&2; exit 1; }; }
get_ssm() {
  local name="$1"
  local val
  if ! val=$(aws ssm get-parameter --name "$name" --with-decryption --query "Parameter.Value" --output text 2>/dev/null); then
    echo "❌ Failed to fetch SSM parameter: $name" >&2
    exit 1
  fi
  if [[ -z "$val" || "$val" == "None" ]]; then
    echo "❌ Empty SSM value for: $name" >&2
    exit 1
  fi
  printf '%s' "$val"
}

log_diag() {
  echo "----- DIAGNOSTICS (docker compose ps) -----"
  docker compose --project-name n8n --env-file "$ENV_FILE" ps || true

  echo "----- DIAGNOSTICS (recent logs) -----"
  for s in n8n postgres nginx; do
    echo "### $s ###"
    docker compose --project-name n8n --env-file "$ENV_FILE" logs --no-color --tail=200 "$s" || true
  done

  echo "----- DOCKER/OS STATUS -----"
  docker version || true
  docker info || true
  df -h || true
  free -m || true
}
trap 'echo "❌ start.sh failed"; log_diag' ERR

# --- Preconditions ---
need aws
need docker
need curl
# Some images alias 'docker compose' & 'docker-compose'; prefer the plugin:
if ! docker compose version >/dev/null 2>&1; then
  echo "❌ docker compose plugin not available" >&2
  exit 1
fi

# 1) Fetch secrets from SSM
echo "🔐 Fetching secrets from Parameter Store..."
POSTGRES_DB=$(get_ssm "/n8n/${ENVIRONMENT}/POSTGRES_DB")
POSTGRES_USER=$(get_ssm "/n8n/${ENVIRONMENT}/POSTGRES_USER")
POSTGRES_PASSWORD=$(get_ssm "/n8n/${ENVIRONMENT}/POSTGRES_PASSWORD")
CF_API_TOKEN=$(get_ssm "/n8n/${ENVIRONMENT}/CF_API_TOKEN")
CF_ACCESS_CLIENT_ID=$(get_ssm "/n8n/${ENVIRONMENT}/CF_ACCESS_CLIENT_ID")
CF_ACCESS_CLIENT_SECRET=$(get_ssm "/n8n/${ENVIRONMENT}/CF_ACCESS_CLIENT_SECRET")

# 2) Write runtime env file for compose
echo "💾 Writing $ENV_FILE"
tmpenv="$(mktemp)"
{
  echo "POSTGRES_DB=$POSTGRES_DB"
  echo "POSTGRES_USER=$POSTGRES_USER"
  echo "POSTGRES_PASSWORD=$POSTGRES_PASSWORD"
  echo "CF_API_TOKEN=$CF_API_TOKEN"
  echo "CF_ACCESS_CLIENT_ID=$CF_ACCESS_CLIENT_ID"
  echo "CF_ACCESS_CLIENT_SECRET=$CF_ACCESS_CLIENT_SECRET"
} > "$tmpenv"
mv "$tmpenv" "$ENV_FILE"
chmod 600 "$ENV_FILE"

# 3) Validate compose before restart
if ! docker compose --project-name n8n --env-file "$ENV_FILE" config -q; then
  echo "❌ docker compose config validation failed" >&2
  exit 1
fi

# 4) Restart stack (use fixed project name so containers don’t orphan)
echo "♻️ Restarting Docker Compose stack..."
docker compose --project-name n8n --env-file "$ENV_FILE" down
# --wait returns non-zero if any service doesn't become healthy
docker compose --project-name n8n --env-file "$ENV_FILE" up -d --wait --no-build

echo "🩺 Verifying via Nginx (max 60s)"
for i in {1..30}; do
  if curl -fsS --max-time 2 http://localhost/nginx-healthz >/dev/null &&
     curl -fsS --max-time 2 http://localhost/upstream-health >/dev/null; then
    echo "✅ Nginx and upstream n8n are healthy"
    exit 0
  fi
  (( i % 10 == 0 )) && docker compose --project-name n8n --env-file "$ENV_FILE" ps
  sleep 1
done

echo "❌ Local readiness timed out"
exit 1

