ALTER TABLE stories
    ADD COLUMN cover_display_storage_key TEXT NULL,
    ADD COLUMN cover_display_file_size BIGINT NULL,
    ADD COLUMN cover_thumbnail_storage_key TEXT NULL,
    ADD COLUMN cover_thumbnail_file_size BIGINT NULL,
    ADD COLUMN cover_mime_type VARCHAR(100) NULL,
    ADD COLUMN cover_updated_at TIMESTAMPTZ NULL;

ALTER TABLE stories
    ADD CONSTRAINT ck_stories_cover_metadata_complete
        CHECK (
            (
                cover_display_storage_key IS NULL
                AND cover_display_file_size IS NULL
                AND cover_thumbnail_storage_key IS NULL
                AND cover_thumbnail_file_size IS NULL
                AND cover_mime_type IS NULL
                AND cover_updated_at IS NULL
            )
            OR
            (
                cover_display_storage_key IS NOT NULL
                AND cover_display_file_size IS NOT NULL
                AND cover_thumbnail_storage_key IS NOT NULL
                AND cover_thumbnail_file_size IS NOT NULL
                AND cover_mime_type IS NOT NULL
                AND cover_updated_at IS NOT NULL
            )
        );

ALTER TABLE stories
    ADD CONSTRAINT ck_stories_cover_file_sizes_positive
        CHECK (
            (cover_display_file_size IS NULL OR cover_display_file_size > 0)
            AND
            (cover_thumbnail_file_size IS NULL OR cover_thumbnail_file_size > 0)
        );

ALTER TABLE stories
    ADD CONSTRAINT ck_stories_cover_storage_keys_nonblank
        CHECK (
            (cover_display_storage_key IS NULL OR btrim(cover_display_storage_key) <> '')
            AND
            (cover_thumbnail_storage_key IS NULL OR btrim(cover_thumbnail_storage_key) <> '')
        );

ALTER TABLE stories
    ADD CONSTRAINT ck_stories_cover_mime_type_nonblank
        CHECK (
            cover_mime_type IS NULL OR btrim(cover_mime_type) <> ''
        );

ALTER TABLE stories
    ADD CONSTRAINT ck_stories_cover_storage_keys_distinct
        CHECK (
            cover_display_storage_key IS NULL
            OR cover_thumbnail_storage_key IS NULL
            OR cover_display_storage_key <> cover_thumbnail_storage_key
        );
