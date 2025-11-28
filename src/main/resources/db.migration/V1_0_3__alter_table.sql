---------------------------------------------------------------
-- 1. INDEXES CHO AUTH / TOKEN / USERS
---------------------------------------------------------------

CREATE INDEX idx_refresh_tokens_user ON refresh_tokens (user_id);
CREATE INDEX idx_refresh_tokens_exp ON refresh_tokens (expires_at);

CREATE INDEX idx_users_email ON users (email);

---------------------------------------------------------------
-- 2. POSTS VÀ TAGS
---------------------------------------------------------------

-- Tối ưu tìm bài theo tag cache JSONB
CREATE INDEX idx_posts_tags_cache_gin ON posts USING GIN (tags_cache);

-- Full Text Search chuẩn SEO + Feed
ALTER TABLE posts
    ADD COLUMN IF NOT EXISTS search_tsv tsvector;

CREATE INDEX IF NOT EXISTS idx_posts_search_tsv
    ON posts USING GIN (search_tsv);

CREATE
OR REPLACE
FUNCTION posts_search_trigger() RETURNS trigger AS $$
BEGIN NEW.search_tsv :=
        setweight(to_tsvector('english', coalesce(NEW.title,'')), 'A') ||
        setweight(to_tsvector('english', coalesce(NEW.content_md,'')), 'B');
RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_posts_search_update
    BEFORE INSERT OR UPDATE ON posts
    FOR EACH ROW EXECUTE FUNCTION posts_search_trigger();

---------------------------------------------------------------
-- 3. COMMENTS TREE PERFORMANCE (LTREE)
---------------------------------------------------------------

CREATE
EXTENSION IF NOT EXISTS ltree;

ALTER TABLE comments
    ADD COLUMN IF NOT EXISTS path ltree;

-- Auto-generate path tree
CREATE
OR REPLACE
FUNCTION set_comment_path() RETURNS trigger AS $$
BEGIN IF NEW.parent_id IS NULL THEN
        NEW.path := NEW.id::text::ltree;
ELSE
SELECT path || NEW.id::text INTO NEW.path
FROM comments
WHERE id = NEW.parent_id;
END IF;
RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_comment_path
    BEFORE INSERT
    ON comments
    FOR EACH ROW EXECUTE FUNCTION set_comment_path();

CREATE INDEX idx_comments_path_gin ON comments USING GIST(path);

---------------------------------------------------------------
-- 4. FOLLOWS POLYMORPHIC INDEX
---------------------------------------------------------------

CREATE INDEX idx_follows_type_target ON follows (target_type, target_id);

---------------------------------------------------------------
-- 5. NOTIFICATION SCALING
---------------------------------------------------------------

CREATE INDEX idx_notifications_user_read ON notifications (user_id, read_at);

---------------------------------------------------------------
-- 6. MEDIA (THIẾU TRONG SCHEMA GỐC) → BẮT BUỘC PHẢI CÓ
---------------------------------------------------------------

CREATE TABLE IF NOT EXISTS media_files
(
    id         BIGSERIAL PRIMARY KEY,
    owner_id   BIGINT      REFERENCES users (id) ON DELETE SET NULL,
    url        TEXT        NOT NULL,
    type       VARCHAR(20) NOT NULL, -- IMAGE/VIDEO/DOC
    size       BIGINT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS post_media
(
    post_id  BIGINT REFERENCES posts (id) ON DELETE CASCADE,
    media_id BIGINT REFERENCES media_files (id) ON DELETE CASCADE,
    PRIMARY KEY (post_id, media_id)
);

CREATE TABLE IF NOT EXISTS comment_media
(
    comment_id BIGINT REFERENCES comments (id) ON DELETE CASCADE,
    media_id   BIGINT REFERENCES media_files (id) ON DELETE CASCADE,
    PRIMARY KEY (comment_id, media_id)
);

---------------------------------------------------------------
-- 7. REPORT EVIDENCE (THIẾU TRONG SCHEMA GỐC)
---------------------------------------------------------------

CREATE TABLE IF NOT EXISTS report_evidences
(
    id         BIGSERIAL PRIMARY KEY,
    report_id  BIGINT REFERENCES reports (id) ON DELETE CASCADE,
    type       VARCHAR(30), -- image/link/text
    url        TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

---------------------------------------------------------------
-- 8. USER ACTIVITY LOG (NỀN TẢNG CHO FEED GỢI Ý)
---------------------------------------------------------------

CREATE TABLE IF NOT EXISTS user_activity_log
(
    id         BIGSERIAL PRIMARY KEY,
    user_id    BIGINT REFERENCES users (id) ON DELETE CASCADE,
    action     VARCHAR(50) NOT NULL,
    metadata   JSONB       DEFAULT '{}'::jsonb,
    device     VARCHAR(100),
    ip         VARCHAR(50),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_user_activity_user ON user_activity_log (user_id);
CREATE INDEX idx_user_activity_action ON user_activity_log (action);