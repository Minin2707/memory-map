CREATE TABLE music_tracks
(
    id UUID PRIMARY KEY,

    title VARCHAR(255) NOT NULL,

    artist VARCHAR(255) NOT NULL,

    duration_seconds INTEGER NOT NULL,

    status VARCHAR(20) NOT NULL,

    sort_order INTEGER NOT NULL,

    storage_key TEXT NOT NULL,

    mime_type VARCHAR(100) NOT NULL,

    file_size BIGINT NOT NULL,

    created_at TIMESTAMPTZ NOT NULL,

    updated_at TIMESTAMPTZ NOT NULL,

    CONSTRAINT uk_music_tracks_storage_key
        UNIQUE (storage_key)
);

ALTER TABLE stories
    ADD COLUMN soundtrack_id UUID NULL;

ALTER TABLE stories
    ADD CONSTRAINT fk_stories_soundtrack
        FOREIGN KEY (soundtrack_id)
            REFERENCES music_tracks(id);
