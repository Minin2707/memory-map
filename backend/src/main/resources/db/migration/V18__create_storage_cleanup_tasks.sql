CREATE TABLE storage_cleanup_tasks
(
    id UUID PRIMARY KEY,

    storage_key TEXT NOT NULL,

    created_at TIMESTAMPTZ NOT NULL,

    next_attempt_at TIMESTAMPTZ NOT NULL,

    attempt_count INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT uq_storage_cleanup_tasks_storage_key
        UNIQUE (storage_key),

    CONSTRAINT ck_storage_cleanup_tasks_storage_key_not_blank
        CHECK (BTRIM(storage_key) <> ''),

    CONSTRAINT ck_storage_cleanup_tasks_attempt_count_non_negative
        CHECK (attempt_count >= 0)
);

CREATE INDEX idx_storage_cleanup_tasks_due
    ON storage_cleanup_tasks(next_attempt_at, created_at, id);
