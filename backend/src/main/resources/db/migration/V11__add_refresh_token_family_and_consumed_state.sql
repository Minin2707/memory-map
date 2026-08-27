ALTER TABLE refresh_tokens
    ADD COLUMN family_id UUID,
    ADD COLUMN consumed_at TIMESTAMPTZ;

UPDATE refresh_tokens
SET family_id = id
WHERE family_id IS NULL;

ALTER TABLE refresh_tokens
    ALTER COLUMN family_id SET NOT NULL;

CREATE INDEX idx_refresh_tokens_family_active
    ON refresh_tokens (family_id)
    WHERE consumed_at IS NULL
      AND revoked_at IS NULL;
