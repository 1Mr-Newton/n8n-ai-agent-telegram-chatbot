-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users table to store information about Telegram users
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    telegram_id BIGINT UNIQUE NOT NULL,
    username VARCHAR(255),
    first_name VARCHAR(255),
    last_name VARCHAR(255),
    language_code VARCHAR(10),
    is_bot BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    is_premium BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_interaction_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- User settings table to store user preferences
CREATE TABLE IF NOT EXISTS user_settings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    notification_enabled BOOLEAN DEFAULT TRUE,
    preferred_language VARCHAR(10) DEFAULT 'en',
    ai_model_preference VARCHAR(50) DEFAULT 'gpt-4o-mini',
    response_format VARCHAR(50) DEFAULT 'text',
    max_tokens INTEGER DEFAULT 1000,
    temperature FLOAT DEFAULT 0.7,
    system_prompt TEXT DEFAULT 'You are a helpful AI assistant.',
    current_session_id UUID DEFAULT uuid_generate_v4(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id)
);

-- Bot commands table to store available commands
CREATE TABLE IF NOT EXISTS bot_commands (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    command_name VARCHAR(100) UNIQUE NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Usage metrics table to track user interactions
CREATE TABLE IF NOT EXISTS usage_metrics (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    command_id UUID REFERENCES bot_commands(id) ON DELETE SET NULL,
    tokens_used INTEGER DEFAULT 0,
    request_timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    response_time_ms INTEGER,
    was_successful BOOLEAN DEFAULT TRUE,
    error_message TEXT,
    request_content_type VARCHAR(50) DEFAULT 'text',
    request_source VARCHAR(50) DEFAULT 'telegram'
);

-- Daily usage summary for analytics
CREATE TABLE IF NOT EXISTS daily_usage_summary (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    total_requests INTEGER DEFAULT 0,
    total_tokens_used INTEGER DEFAULT 0,
    unique_commands_used INTEGER DEFAULT 0,
    UNIQUE(user_id, date)
);

-- Rate limiting table
CREATE TABLE IF NOT EXISTS rate_limits (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    daily_limit INTEGER DEFAULT 100,
    monthly_limit INTEGER DEFAULT 3000,
    current_daily_usage INTEGER DEFAULT 0,
    current_monthly_usage INTEGER DEFAULT 0,
    last_reset_daily TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_reset_monthly TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id)
);

-- Create indexes if they don't exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_usage_metrics_user_id') THEN
        CREATE INDEX idx_usage_metrics_user_id ON usage_metrics(user_id);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_usage_metrics_timestamp') THEN
        CREATE INDEX idx_usage_metrics_timestamp ON usage_metrics(request_timestamp);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_daily_usage_summary_date') THEN
        CREATE INDEX idx_daily_usage_summary_date ON daily_usage_summary(date);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_users_telegram_id') THEN
        CREATE INDEX idx_users_telegram_id ON users(telegram_id);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_users_is_premium') THEN
        CREATE INDEX idx_users_is_premium ON users(is_premium);
    END IF;
END
$$;

-- Create or replace the function for the trigger
CREATE OR REPLACE FUNCTION create_user_related_records()
RETURNS TRIGGER AS $$
BEGIN
    -- Insert default user settings
    INSERT INTO user_settings (user_id)
    VALUES (NEW.id)
    ON CONFLICT (user_id) DO NOTHING;
    
    -- Insert default rate limits
    INSERT INTO rate_limits (user_id)
    VALUES (NEW.id)
    ON CONFLICT (user_id) DO NOTHING;
    
    -- Insert initial daily usage summary for today
    INSERT INTO daily_usage_summary (user_id, date)
    VALUES (NEW.id, CURRENT_DATE)
    ON CONFLICT (user_id, date) DO NOTHING;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop the trigger if it exists and recreate it
DROP TRIGGER IF EXISTS after_user_insert ON users;
CREATE TRIGGER after_user_insert
AFTER INSERT ON users
FOR EACH ROW
EXECUTE FUNCTION create_user_related_records();
