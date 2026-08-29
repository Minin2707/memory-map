ALTER TABLE users
    ADD COLUMN deleted_at TIMESTAMPTZ NULL;

ALTER TABLE users
    ALTER COLUMN google_subject DROP NOT NULL;

ALTER TABLE users
    ADD CONSTRAINT ck_users_deleted_google_subject
        CHECK (deleted_at IS NULL OR google_subject IS NULL);

ALTER TABLE stories
    DROP CONSTRAINT fk_stories_owner;

ALTER TABLE stories
    ADD CONSTRAINT fk_stories_owner
        FOREIGN KEY (owner_id)
        REFERENCES users(id)
        ON DELETE RESTRICT;

CREATE INDEX idx_memories_created_by
    ON memories(created_by);

CREATE INDEX idx_invites_created_by_unused
    ON invites(created_by)
    WHERE used_at IS NULL;

CREATE INDEX idx_refresh_tokens_user_id
    ON refresh_tokens(user_id);
