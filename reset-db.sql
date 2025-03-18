-- Drop triggers first
DROP TRIGGER IF EXISTS after_user_insert ON users;

-- Drop functions
DROP FUNCTION IF EXISTS create_user_related_records();

-- Drop tables in reverse order of dependencies
DROP TABLE IF EXISTS rate_limits CASCADE;
DROP TABLE IF EXISTS daily_usage_summary CASCADE;
DROP TABLE IF EXISTS usage_metrics CASCADE;
DROP TABLE IF EXISTS bot_commands CASCADE;
DROP TABLE IF EXISTS user_settings CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- Drop indexes (though they should be dropped with their tables)
DROP INDEX IF EXISTS idx_usage_metrics_user_id;
DROP INDEX IF EXISTS idx_usage_metrics_timestamp;
DROP INDEX IF EXISTS idx_daily_usage_summary_date;
DROP INDEX IF EXISTS idx_users_telegram_id;
DROP INDEX IF EXISTS idx_users_is_premium;

-- Drop extensions if no longer needed
-- Note: Only uncomment this if you're sure no other database objects need this extension
-- DROP EXTENSION IF EXISTS "uuid-ossp";

-- Vacuum the database to reclaim storage
VACUUM FULL; 