-- 1. USERS & AUTH -----------------------------------------------------------
CREATE TABLE users
(
    id            BIGSERIAL PRIMARY KEY,
    email         VARCHAR(150) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    display_name  VARCHAR(80)  NOT NULL,
    avatar_url    VARCHAR(255),
    bio           TEXT,
    role          VARCHAR(20)  NOT NULL DEFAULT 'USER',   -- USER/MOD/ADMIN
    status        VARCHAR(20)  NOT NULL DEFAULT 'ACTIVE', -- ACTIVE/BANNED/PENDING
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at    TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE user_profiles
(
    user_id     BIGINT PRIMARY KEY REFERENCES users (id) ON DELETE CASCADE,
    website     VARCHAR(255),
    github      VARCHAR(255),
    linkedin    VARCHAR(255),
    location    VARCHAR(120),
    timezone    VARCHAR(60),
    preferences JSONB                DEFAULT '{}'::jsonb,
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE refresh_tokens
(
    id         BIGSERIAL PRIMARY KEY,
    user_id    BIGINT       NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    token      VARCHAR(255) NOT NULL,
    expires_at TIMESTAMPTZ  NOT NULL,
    revoked    BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 2. TAGS & CATEGORIES ------------------------------------------------------
CREATE TABLE tags
(
    id          BIGSERIAL PRIMARY KEY,
    name        VARCHAR(50) NOT NULL UNIQUE,
    slug        VARCHAR(60) NOT NULL UNIQUE,
    description TEXT,
    color       VARCHAR(20),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE categories
(
    id          BIGSERIAL PRIMARY KEY,
    name        VARCHAR(80) NOT NULL,
    slug        VARCHAR(90) NOT NULL UNIQUE,
    description TEXT,
    parent_id   BIGINT      REFERENCES categories (id) ON DELETE SET NULL,
    sort_order  INT                  DEFAULT 0,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 3. POSTS ------------------------------------------------------------------
CREATE TABLE posts
(
    id               BIGSERIAL PRIMARY KEY,
    author_id        BIGINT       NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    title            VARCHAR(200) NOT NULL,
    slug             VARCHAR(220) NOT NULL UNIQUE,
    content_md       TEXT         NOT NULL,
    content_html     TEXT         NOT NULL,
    excerpt          VARCHAR(300),
    status           VARCHAR(20)  ,
    type             VARCHAR(20) ,
    visibility       VARCHAR(20)  NOT NULL DEFAULT 'PUBLIC',
    allow_comments   BOOLEAN               DEFAULT TRUE,
    view_count       INT          NOT NULL DEFAULT 0,
    vote_score       INT          NOT NULL DEFAULT 0,
    tags_cache       JSONB                 DEFAULT '[]'::jsonb,
    category_id      BIGINT       REFERENCES categories (id) ON DELETE SET NULL,
    created_at       TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at       TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    published_at     TIMESTAMPTZ,
    last_activity_at TIMESTAMPTZ
);

CREATE TABLE post_revisions
(
    id         BIGSERIAL PRIMARY KEY,
    post_id    BIGINT      NOT NULL REFERENCES posts (id) ON DELETE CASCADE,
    editor_id  BIGINT      NOT NULL REFERENCES users (id) ON DELETE SET NULL,
    content_md TEXT        NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE post_tags
(
    post_id BIGINT NOT NULL REFERENCES posts (id) ON DELETE CASCADE,
    tag_id  BIGINT NOT NULL REFERENCES tags (id) ON DELETE CASCADE,
    PRIMARY KEY (post_id, tag_id)
);

-- 4. COMMENTS & REACTIONS ---------------------------------------------------
CREATE TABLE comments
(
    id           BIGSERIAL PRIMARY KEY,
    post_id      BIGINT      NOT NULL REFERENCES posts (id) ON DELETE CASCADE,
    parent_id    BIGINT REFERENCES comments (id) ON DELETE CASCADE,
    author_id    BIGINT      NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    content_md   TEXT        NOT NULL,
    content_html TEXT        NOT NULL,
    vote_score   INT         NOT NULL DEFAULT 0,
    status       VARCHAR(20) NOT NULL DEFAULT 'VISIBLE', -- VISIBLE/DELETED/MOD_HIDDEN
    created_at   TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE comment_votes
(
    comment_id BIGINT      NOT NULL REFERENCES comments (id) ON DELETE CASCADE,
    user_id    BIGINT      NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    value      SMALLINT    NOT NULL CHECK (value IN (-1, 1)),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (comment_id, user_id)
);

CREATE TABLE comment_reactions
(
    id         BIGSERIAL PRIMARY KEY,
    comment_id BIGINT      NOT NULL REFERENCES comments (id) ON DELETE CASCADE,
    user_id    BIGINT      NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    type       VARCHAR(30) NOT NULL, -- LIKE/CLAP/LAUGH...
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (comment_id, user_id, type)
);

-- 5. GROUPS & MEMBERS -------------------------------------------------------
CREATE TABLE groups
(
    id          BIGSERIAL PRIMARY KEY,
    name        VARCHAR(120) NOT NULL,
    slug        VARCHAR(140) NOT NULL UNIQUE,
    description TEXT,
    visibility  VARCHAR(20)  NOT NULL DEFAULT 'PUBLIC', -- PUBLIC/PRIVATE/SECRET
    join_policy VARCHAR(20)  NOT NULL DEFAULT 'OPEN',   -- OPEN/REQUEST/INVITE
    owner_id    BIGINT       NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE group_members
(
    group_id  BIGINT      NOT NULL REFERENCES groups (id) ON DELETE CASCADE,
    user_id   BIGINT      NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    role      VARCHAR(20) NOT NULL DEFAULT 'MEMBER', -- MEMBER/MODERATOR/OWNER
    status    VARCHAR(20) NOT NULL DEFAULT 'ACTIVE', -- ACTIVE/PENDING/BANNED
    joined_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (group_id, user_id)
);

CREATE TABLE group_posts
(
    group_id BIGINT NOT NULL REFERENCES groups (id) ON DELETE CASCADE,
    post_id  BIGINT NOT NULL REFERENCES posts (id) ON DELETE CASCADE,
    PRIMARY KEY (group_id, post_id)
);

-- 6. INTERACTION & GAMIFICATION --------------------------------------------
CREATE TABLE follows
(
    id          BIGSERIAL PRIMARY KEY,
    follower_id BIGINT      NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    target_type VARCHAR(20) NOT NULL, -- USER/TAG/POST
    target_id   BIGINT      NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (follower_id, target_type, target_id)
);

CREATE TABLE bookmarks
(
    user_id    BIGINT      NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    post_id    BIGINT      NOT NULL REFERENCES posts (id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, post_id)
);

CREATE TABLE notifications
(
    id         BIGSERIAL PRIMARY KEY,
    user_id    BIGINT      NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    type       VARCHAR(30) NOT NULL,
    payload    JSONB       NOT NULL,
    read_at    TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE user_reputation
(
    user_id BIGINT PRIMARY KEY REFERENCES users (id) ON DELETE CASCADE,
    score   INT   NOT NULL DEFAULT 0,
    history JSONB NOT NULL DEFAULT '[]'::jsonb
);

CREATE TABLE badges
(
    id          BIGSERIAL PRIMARY KEY,
    name        VARCHAR(80) NOT NULL,
    description TEXT,
    icon        VARCHAR(120),
    criteria    JSONB       NOT NULL,
    type        VARCHAR(20) NOT NULL DEFAULT 'AUTOMATIC',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE user_badges
(
    user_id    BIGINT      NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    badge_id   BIGINT      NOT NULL REFERENCES badges (id) ON DELETE CASCADE,
    awarded_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, badge_id)
);

-- 7. MODERATION & AUDIT -----------------------------------------------------
CREATE TABLE reports
(
    id          BIGSERIAL PRIMARY KEY,
    target_type VARCHAR(20) NOT NULL,                -- POST/COMMENT/USER
    target_id   BIGINT      NOT NULL,
    reporter_id BIGINT      NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    reason_code VARCHAR(30) NOT NULL,
    description TEXT,
    status      VARCHAR(20) NOT NULL DEFAULT 'OPEN', -- OPEN/UNDER_REVIEW/RESOLVED
    created_at  TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMPTZ
);

CREATE TABLE audit_logs
(
    id          BIGSERIAL PRIMARY KEY,
    actor_id    BIGINT      REFERENCES users (id) ON DELETE SET NULL,
    action      VARCHAR(50) NOT NULL,
    target_type VARCHAR(20) NOT NULL,
    target_id   BIGINT,
    metadata    JSONB                DEFAULT '{}'::jsonb,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);