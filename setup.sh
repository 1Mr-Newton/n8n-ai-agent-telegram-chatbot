#!/bin/bash

# Load environment variables from .env file
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

# Check if required environment variables are set
if [ -z "$DATABASE_URL" ]; then
    echo "Error: DATABASE_URL is not set in .env file"
    exit 1
fi

# Set default values for configuration if not set in .env
export DEFAULT_AI_MODEL=${DEFAULT_AI_MODEL:-"gpt-4o-mini"}
export DEFAULT_MAX_TOKENS=${DEFAULT_MAX_TOKENS:-"1000"}
export DEFAULT_TEMPERATURE=${DEFAULT_TEMPERATURE:-"0.7"}
export DEFAULT_SYSTEM_PROMPT=${DEFAULT_SYSTEM_PROMPT:-"You are a helpful AI assistant."}
export DEFAULT_DAILY_LIMIT=${DEFAULT_DAILY_LIMIT:-"100"}
export DEFAULT_MONTHLY_LIMIT=${DEFAULT_MONTHLY_LIMIT:-"3000"}

# Extract database name from DATABASE_URL
DB_NAME=$(echo $DATABASE_URL | sed -n 's/.*\/\([^?]*\).*/\1/p')

# Create database if it doesn't exist
createdb $DB_NAME 2>/dev/null || true

# Set PostgreSQL session variables
export PGOPTIONS="-c DEFAULT_AI_MODEL='$DEFAULT_AI_MODEL' \
                  -c DEFAULT_MAX_TOKENS='$DEFAULT_MAX_TOKENS' \
                  -c DEFAULT_TEMPERATURE='$DEFAULT_TEMPERATURE' \
                  -c DEFAULT_SYSTEM_PROMPT='$DEFAULT_SYSTEM_PROMPT' \
                  -c DEFAULT_DAILY_LIMIT='$DEFAULT_DAILY_LIMIT' \
                  -c DEFAULT_MONTHLY_LIMIT='$DEFAULT_MONTHLY_LIMIT'"

# Run the SQL file
psql "$DATABASE_URL" -f db.sql

echo "Database setup completed successfully!" 