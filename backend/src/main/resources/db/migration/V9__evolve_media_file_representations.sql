ALTER TABLE media_files
    RENAME COLUMN storage_key TO display_storage_key;

ALTER TABLE media_files
    RENAME COLUMN file_size TO display_file_size;

ALTER TABLE media_files
    ADD COLUMN thumbnail_storage_key TEXT,
    ADD COLUMN thumbnail_file_size BIGINT;

ALTER TABLE media_files
    ADD CONSTRAINT ck_media_files_display_file_size_positive
        CHECK (display_file_size IS NULL OR display_file_size > 0),
    ADD CONSTRAINT ck_media_files_display_storage_key_not_blank
        CHECK (btrim(display_storage_key) <> ''),
    ADD CONSTRAINT ck_media_files_thumbnail_file_size_positive
        CHECK (thumbnail_file_size IS NULL OR thumbnail_file_size > 0),
    ADD CONSTRAINT ck_media_files_mime_type_not_blank
        CHECK (mime_type IS NULL OR btrim(mime_type) <> ''),
    ADD CONSTRAINT ck_media_files_thumbnail_storage_key_not_blank
        CHECK (
            thumbnail_storage_key IS NULL
            OR btrim(thumbnail_storage_key) <> ''
        ),
    ADD CONSTRAINT ck_media_files_thumbnail_representation_complete
        CHECK (
            (thumbnail_storage_key IS NULL AND thumbnail_file_size IS NULL)
            OR
            (thumbnail_storage_key IS NOT NULL AND thumbnail_file_size IS NOT NULL)
        ),
    ADD CONSTRAINT ck_media_files_representation_storage_keys_differ
        CHECK (
            thumbnail_storage_key IS NULL
            OR display_storage_key <> thumbnail_storage_key
        );
