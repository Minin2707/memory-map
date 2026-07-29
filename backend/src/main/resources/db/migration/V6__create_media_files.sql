CREATE TABLE media_files
(
    id UUID PRIMARY KEY,

    memory_id UUID NOT NULL,

    media_type VARCHAR(20) NOT NULL,

    file_size BIGINT,

    mime_type VARCHAR(100),

    storage_key TEXT NOT NULL,

    created_at TIMESTAMPTZ NOT NULL,

    CONSTRAINT fk_media_files_memory
        FOREIGN KEY (memory_id)
            REFERENCES memories(id)
            ON DELETE CASCADE
);

CREATE INDEX idx_media_files_memory
    ON media_files(memory_id);
