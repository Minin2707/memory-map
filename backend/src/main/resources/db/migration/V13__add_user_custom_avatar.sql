ALTER TABLE users
    ADD COLUMN custom_avatar_storage_key TEXT NULL,
    ADD COLUMN custom_avatar_updated_at TIMESTAMPTZ NULL;

ALTER TABLE users
    ADD CONSTRAINT ck_users_custom_avatar_pair
        CHECK (
            (custom_avatar_storage_key IS NULL AND custom_avatar_updated_at IS NULL)
            OR
            (custom_avatar_storage_key IS NOT NULL AND custom_avatar_updated_at IS NOT NULL)
        );
