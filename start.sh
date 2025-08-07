#!/bin/bash
set -e

# Select environment: dev or prod (default: dev)
ENVIRONMENT=${1:-dev}

echo "▶️ Starting n8n stack for environment: $ENVIRONMENT"

# Step 1: Fetch secrets from AWS Parameter Store
export POSTGRES_DB=$(aws ssm get-parameter --name "/n8n/${ENVIRONMENT}/POSTGRES_DB" --with-decryption --query "Parameter.Value" --output text)
export POSTGRES_USER=$(aws ssm get-parameter --name "/n8n/${ENVIRONMENT}/POSTGRES_USER" --with-decryption --query "Parameter.Value" --output text)
export POSTGRES_PASSWORD=$(aws ssm get-parameter --name "/n8n/${ENVIRONMENT}/POSTGRES_PASSWORD" --with-decryption --query "Parameter.Value" --output text)

# Step 2: Check if n8n or postgres containers are already running
echo "📦 Checking for running containers..."
if docker compose ps | grep -q "n8n"; then
  echo "🛑 Existing n8n stack detected. Bringing it down first..."
  docker compose down
fi

# Step 3: Start the stack
echo "🚀 Starting n8n with updated secrets for '$ENVIRONMENT'..."
docker compose up -d

# Step 4: Tail logs for confirmation (optional)
echo "📋 Tailing n8n logs (press Ctrl+C to stop)..."
docker compose logs -f n8n
