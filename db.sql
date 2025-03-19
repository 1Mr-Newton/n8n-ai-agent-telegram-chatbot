-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";  -- For encryption functions

-- Create a function to get environment variable value
CREATE OR REPLACE FUNCTION get_env_var(var_name text)
RETURNS text AS $$
BEGIN
    RETURN current_setting(var_name, true);
EXCEPTION
    WHEN OTHERS THEN
        RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- System constants table
CREATE TABLE IF NOT EXISTS system_constants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    constant_key VARCHAR(100) UNIQUE NOT NULL,
    constant_value JSONB NOT NULL,
    category VARCHAR(50) NOT NULL,
    description TEXT,
    is_encrypted BOOLEAN DEFAULT FALSE,
    created_by UUID REFERENCES admin_users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Function to get system constant
CREATE OR REPLACE FUNCTION get_system_constant(p_key VARCHAR)
RETURNS JSONB AS $$
BEGIN
    RETURN (SELECT constant_value FROM system_constants WHERE constant_key = p_key);
EXCEPTION
    WHEN OTHERS THEN
        RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Function to set system constant
CREATE OR REPLACE FUNCTION set_system_constant(
    p_key VARCHAR,
    p_value JSONB,
    p_category VARCHAR,
    p_description TEXT,
    p_admin_id UUID
)
RETURNS VOID AS $$
BEGIN
    INSERT INTO system_constants (constant_key, constant_value, category, description, created_by)
    VALUES (p_key, p_value, p_category, p_description, p_admin_id)
    ON CONFLICT (constant_key) 
    DO UPDATE SET 
        constant_value = p_value,
        updated_at = CURRENT_TIMESTAMP;
END;
$$ LANGUAGE plpgsql;

-- Add trigger for system_constants
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'update_system_constants_updated_at') THEN
        CREATE TRIGGER update_system_constants_updated_at
            BEFORE UPDATE ON system_constants
            FOR EACH ROW
            EXECUTE FUNCTION update_updated_at_column();
    END IF;
END
$$;

-- Insert default system constants
INSERT INTO system_constants (constant_key, constant_value, category, description)
VALUES 
    -- API Related Constants
    ('API_RATE_LIMITS', jsonb_build_object(
        'standard_user', jsonb_build_object(
            'requests_per_second', 2,
            'burst_limit', 5,
            'cooldown_seconds', 60
        ),
        'premium_user', jsonb_build_object(
            'requests_per_second', 5,
            'burst_limit', 10,
            'cooldown_seconds', 30
        )
    ), 'API', 'API rate limiting configuration'),

    -- Security Constants
    ('SECURITY_SETTINGS', jsonb_build_object(
        'max_login_attempts', 5,
        'lockout_duration_minutes', 30,
        'password_expiry_days', 90,
        'session_timeout_minutes', 60,
        'require_2fa', true
    ), 'SECURITY', 'Security-related constants'),

    -- Message Constants
    ('MESSAGE_LIMITS', jsonb_build_object(
        'max_message_length', 4096,
        'min_message_length', 1,
        'max_media_size_mb', 50,
        'allowed_mime_types', array['image/jpeg', 'image/png', 'image/gif', 'video/mp4']
    ), 'MESSAGES', 'Message handling constants'),

    -- User Preferences Defaults
    ('DEFAULT_USER_PREFERENCES', jsonb_build_object(
        'language', 'en',
        'timezone', 'UTC',
        'notifications', jsonb_build_object(
            'email', true,
            'telegram', true,
            'daily_summary', false
        ),
        'privacy', jsonb_build_object(
            'share_usage_stats', true,
            'allow_ai_training', false
        )
    ), 'USERS', 'Default user preference settings'),

    -- System Limits
    ('SYSTEM_LIMITS', jsonb_build_object(
        'max_concurrent_requests', 100,
        'max_connections_per_user', 5,
        'max_session_duration_hours', 24,
        'maintenance_window', jsonb_build_object(
            'start_hour', 2,
            'duration_minutes', 120,
            'timezone', 'UTC'
        )
    ), 'SYSTEM', 'System-wide limitation constants'),

    -- AI Model Constants
    ('AI_MODEL_SETTINGS', jsonb_build_object(
        'context_window_size', jsonb_build_object(
            'gpt-4o-mini', 8192,
            'gpt-4', 32768
        ),
        'token_limits', jsonb_build_object(
            'max_prompt_tokens', 4000,
            'max_completion_tokens', 4000
        ),
        'temperature_range', jsonb_build_object(
            'min', 0.1,
            'max', 1.0,
            'default', 0.7
        )
    ), 'AI', 'AI model configuration constants'),

    -- Premium Features
    ('PREMIUM_FEATURES', jsonb_build_object(
        'models', array['gpt-4', 'claude-2'],
        'max_tokens', 8000,
        'priority_support', true,
        'custom_instructions', true,
        'advanced_analytics', true
    ), 'PREMIUM', 'Premium user feature flags and limits'),

    -- Bot Configuration
    ('BOT_SETTINGS', jsonb_build_object(
        'inline_mode', jsonb_build_object(
            'enabled', true,
            'cache_time', 300,
            'is_personal', true
        ),
        'commands', jsonb_build_object(
            'show_in_menu', true,
            'menu_language', 'en',
            'case_sensitive', false
        ),
        'groups', jsonb_build_object(
            'allowed_types', array['private', 'group', 'supergroup'],
            'require_admin', true,
            'max_members', 10000
        ),
        'media', jsonb_build_object(
            'allow_voice', true,
            'allow_video', true,
            'allow_photos', true,
            'max_file_size_mb', 50
        )
    ), 'BOT', 'Telegram bot configuration settings'),

    -- Webhook Settings
    ('WEBHOOK_CONFIG', jsonb_build_object(
        'enabled', true,
        'max_connections', 100,
        'allowed_updates', array['message', 'edited_message', 'callback_query', 'inline_query'],
        'retry_settings', jsonb_build_object(
            'max_attempts', 3,
            'delay_seconds', 5
        )
    ), 'BOT', 'Webhook configuration settings'),

    -- Integration Settings
    ('INTEGRATION_SETTINGS', jsonb_build_object(
        'n8n', jsonb_build_object(
            'webhook_timeout', 120,
            'max_retries', 3,
            'error_workflow', 'error_handler'
        ),
        'monitoring', jsonb_build_object(
            'enabled', true,
            'interval_seconds', 300,
            'alert_threshold', 0.95
        )
    ), 'INTEGRATIONS', 'Third-party integration settings')
ON CONFLICT (constant_key) DO NOTHING;

-- Admin users table
CREATE TABLE IF NOT EXISTS admin_users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    telegram_id BIGINT UNIQUE NOT NULL,
    username VARCHAR(255),
    first_name VARCHAR(255),
    last_name VARCHAR(255),
    role VARCHAR(50) DEFAULT 'admin',
    permissions JSONB DEFAULT '{"manage_users": true, "view_analytics": true, "manage_settings": true}'::jsonb,
    is_active BOOLEAN DEFAULT TRUE,
    last_login TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- System settings table for global configuration
CREATE TABLE IF NOT EXISTS system_settings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    setting_key VARCHAR(100) UNIQUE NOT NULL,
    setting_value JSONB,
    description TEXT,
    is_public BOOLEAN DEFAULT FALSE,
    created_by UUID REFERENCES admin_users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Admin audit log
CREATE TABLE IF NOT EXISTS admin_audit_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    admin_id UUID REFERENCES admin_users(id),
    action VARCHAR(100) NOT NULL,
    entity_type VARCHAR(50) NOT NULL,
    entity_id UUID,
    changes JSONB,
    ip_address VARCHAR(45),
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- System health metrics
CREATE TABLE IF NOT EXISTS system_health (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    metric_name VARCHAR(100) NOT NULL,
    metric_value JSONB,
    status VARCHAR(50) DEFAULT 'healthy',
    last_check TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

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
    ai_model_preference VARCHAR(50) DEFAULT current_setting('DEFAULT_AI_MODEL', true),
    response_format VARCHAR(50) DEFAULT 'text',
    max_tokens INTEGER DEFAULT current_setting('DEFAULT_MAX_TOKENS', true)::integer,
    temperature FLOAT DEFAULT current_setting('DEFAULT_TEMPERATURE', true)::float,
    system_prompt TEXT DEFAULT current_setting('DEFAULT_SYSTEM_PROMPT', true),
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
    daily_limit INTEGER DEFAULT current_setting('DEFAULT_DAILY_LIMIT', true)::integer,
    monthly_limit INTEGER DEFAULT current_setting('DEFAULT_MONTHLY_LIMIT', true)::integer,
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

-- Create indexes for admin tables
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_admin_users_telegram_id') THEN
        CREATE INDEX idx_admin_users_telegram_id ON admin_users(telegram_id);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_admin_audit_log_admin_id') THEN
        CREATE INDEX idx_admin_audit_log_admin_id ON admin_audit_log(admin_id);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_admin_audit_log_created_at') THEN
        CREATE INDEX idx_admin_audit_log_created_at ON admin_audit_log(created_at);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_system_health_metric_name') THEN
        CREATE INDEX idx_system_health_metric_name ON system_health(metric_name);
    END IF;
END
$$;

-- Create trigger for updating updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Add updated_at triggers to relevant tables
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'update_admin_users_updated_at') THEN
        CREATE TRIGGER update_admin_users_updated_at
            BEFORE UPDATE ON admin_users
            FOR EACH ROW
            EXECUTE FUNCTION update_updated_at_column();
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'update_system_settings_updated_at') THEN
        CREATE TRIGGER update_system_settings_updated_at
            BEFORE UPDATE ON system_settings
            FOR EACH ROW
            EXECUTE FUNCTION update_updated_at_column();
    END IF;
END
$$;

-- Insert default system settings
INSERT INTO system_settings (setting_key, setting_value, description, is_public)
VALUES 
    ('maintenance_mode', '{"enabled": false, "message": "System is under maintenance"}', 'Maintenance mode configuration', true),
    ('ai_models', '{"available_models": ["gpt-4o-mini", "gpt-4"], "default_model": "gpt-4o-mini"}', 'Available AI models configuration', true),
    ('rate_limits', '{"default_daily": 100, "default_monthly": 3000, "premium_daily": 500, "premium_monthly": 15000}', 'Rate limiting configuration', true)
ON CONFLICT (setting_key) DO NOTHING;

-- Secure credentials table for API keys and sensitive data
CREATE TABLE IF NOT EXISTS secure_credentials (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    credential_key VARCHAR(100) UNIQUE NOT NULL,
    credential_value TEXT NOT NULL,
    is_encrypted BOOLEAN DEFAULT TRUE,
    description TEXT,
    last_rotated TIMESTAMP WITH TIME ZONE,
    expiry_date TIMESTAMP WITH TIME ZONE,
    created_by UUID REFERENCES admin_users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Function to securely store credential
CREATE OR REPLACE FUNCTION set_credential(
    p_key VARCHAR,
    p_value TEXT,
    p_encrypt BOOLEAN DEFAULT TRUE,
    p_description TEXT DEFAULT NULL,
    p_admin_id UUID DEFAULT NULL
)
RETURNS VOID AS $$
BEGIN
    INSERT INTO secure_credentials (
        credential_key,
        credential_value,
        is_encrypted,
        description,
        created_by,
        last_rotated
    )
    VALUES (
        p_key,
        CASE WHEN p_encrypt THEN 
            encode(encrypt(p_value::bytea, current_setting('app.encryption_key'), 'aes'), 'base64')
        ELSE p_value END,
        p_encrypt,
        p_description,
        p_admin_id,
        CURRENT_TIMESTAMP
    )
    ON CONFLICT (credential_key) 
    DO UPDATE SET 
        credential_value = CASE WHEN p_encrypt THEN 
            encode(encrypt(p_value::bytea, current_setting('app.encryption_key'), 'aes'), 'base64')
        ELSE p_value END,
        last_rotated = CURRENT_TIMESTAMP,
        updated_at = CURRENT_TIMESTAMP;
END;
$$ LANGUAGE plpgsql;

-- Function to get credential
CREATE OR REPLACE FUNCTION get_credential(p_key VARCHAR)
RETURNS TEXT AS $$
DECLARE
    v_value TEXT;
    v_is_encrypted BOOLEAN;
BEGIN
    SELECT credential_value, is_encrypted 
    INTO v_value, v_is_encrypted 
    FROM secure_credentials 
    WHERE credential_key = p_key;

    IF v_is_encrypted THEN
        RETURN convert_from(
            decrypt(
                decode(v_value, 'base64'), 
                current_setting('app.encryption_key'),
                'aes'
            ),
            'UTF8'
        );
    ELSE
        RETURN v_value;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Insert default secure credentials (encrypted)
DO $$
BEGIN
    -- Only insert if encryption key is set
    IF current_setting('app.encryption_key', true) IS NOT NULL THEN
        PERFORM set_credential('TELEGRAM_BOT_TOKEN', current_setting('TELEGRAM_BOT_TOKEN', true), true, 'Telegram Bot API Token');
        PERFORM set_credential('OPENAI_API_KEY', current_setting('AI_API_KEY', true), true, 'OpenAI API Key');
        PERFORM set_credential('N8N_WEBHOOK_URL', 'https://your-n8n-instance/webhook/telegram', false, 'n8n Webhook URL');
        PERFORM set_credential('WEBHOOK_SECRET', gen_random_uuid()::text, true, 'Webhook verification secret');
    END IF;
END $$;
