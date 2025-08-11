#!/bin/bash
set -e

# Select environment: dev or prod (default: dev)
ENVIRONMENT=${1:-dev}
DEPLOY_DIR="/home/ubuntu/n8n"
ENV_FILE="$DEPLOY_DIR/.env.runtime"
echo "Starting n8n stack for environment: $ENVIRONMENT"

# Step 1: Pull latest code
echo "📥 Fetching latest code from origin/main..."
cd "$DEPLOY_DIR"
git fetch origin main
git reset --hard origin/main

# Step 2: Fetch secrets from AWS SSM Parameter Store
export POSTGRES_DB=$(aws ssm get-parameter --name "/n8n/${ENVIRONMENT}/POSTGRES_DB" --with-decryption --query "Parameter.Value" --output text)
export POSTGRES_USER=$(aws ssm get-parameter --name "/n8n/${ENVIRONMENT}/POSTGRES_USER" --with-decryption --query "Parameter.Value" --output text)
export POSTGRES_PASSWORD=$(aws ssm get-parameter --name "/n8n/${ENVIRONMENT}/POSTGRES_PASSWORD" --with-decryption --query "Parameter.Value" --output text)

# Step 3: Generate runtime .env file for Docker Compose
echo "💾 Writing secrets to temporary runtime env file..."
echo "POSTGRES_DB=$POSTGRES_DB" > "$ENV_FILE"
echo "POSTGRES_USER=$POSTGRES_USER" >> "$ENV_FILE"
echo "POSTGRES_PASSWORD=$POSTGRES_PASSWORD" >> "$ENV_FILE"

# Step 4: Check if n8n or postgres containers are already running
echo "Checking for running containers..."
if docker compose ps | grep -q "n8n"; then
  echo "Existing n8n stack detected. Restarting Docker Compose stack using $ENV_FILE..."
  docker compose --env-file "$ENV_FILE" down
fi

# Step 5: Start the stack
echo "🚀 Starting n8n with updated secrets for '$ENVIRONMENT'..."
docker compose --env-file "$ENV_FILE" up -d

# Step 6: Optionally show logs if run interactively
if [ -z "$CI" ]; then
  echo "📋 Tailing n8n logs (press Ctrl+C to stop)..."
  docker compose --env-file "$ENV_FILE" logs -f n8n
fi
