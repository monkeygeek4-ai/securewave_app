-- Миграция для таблиц модерации контента
-- Требуется для соответствия Apple Guideline 1.2

-- Таблица жалоб на контент
CREATE TABLE IF NOT EXISTS content_reports (
    id SERIAL PRIMARY KEY,
    reporter_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reported_user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    message_id INTEGER REFERENCES messages(id) ON DELETE SET NULL,
    chat_id INTEGER REFERENCES chats(id) ON DELETE SET NULL,
    report_type VARCHAR(50) NOT NULL,  -- spam, harassment, inappropriate, violence, hate_speech, other
    description TEXT,
    status VARCHAR(20) DEFAULT 'pending',  -- pending, reviewed, resolved, dismissed
    moderator_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
    moderator_notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE
);

-- Таблица блокировок между пользователями
CREATE TABLE IF NOT EXISTS user_blocks (
    id SERIAL PRIMARY KEY,
    blocker_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    blocked_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(blocker_id, blocked_id)
);

-- Таблица банов от администрации
CREATE TABLE IF NOT EXISTS user_bans (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    banned_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
    reason TEXT NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE,  -- NULL = перманентный бан
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Лог действий модераторов
CREATE TABLE IF NOT EXISTS moderation_log (
    id SERIAL PRIMARY KEY,
    action VARCHAR(50) NOT NULL,  -- delete, ban, unban, warn, resolve_report
    target_type VARCHAR(20) NOT NULL,  -- user, message, chat, report
    target_id INTEGER NOT NULL,
    admin_username VARCHAR(100),
    reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Согласие с EULA
ALTER TABLE users ADD COLUMN IF NOT EXISTS eula_accepted_at TIMESTAMP WITH TIME ZONE;

-- Индексы для быстрого поиска
CREATE INDEX IF NOT EXISTS idx_content_reports_status ON content_reports(status);
CREATE INDEX IF NOT EXISTS idx_content_reports_created ON content_reports(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_content_reports_reported_user ON content_reports(reported_user_id);
CREATE INDEX IF NOT EXISTS idx_user_blocks_blocker ON user_blocks(blocker_id);
CREATE INDEX IF NOT EXISTS idx_user_blocks_blocked ON user_blocks(blocked_id);
CREATE INDEX IF NOT EXISTS idx_user_bans_user ON user_bans(user_id);
CREATE INDEX IF NOT EXISTS idx_user_bans_expires ON user_bans(expires_at);
