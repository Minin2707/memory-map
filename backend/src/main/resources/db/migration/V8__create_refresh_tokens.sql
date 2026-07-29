CREATE TABLE refresh_tokens
(
    id UUID PRIMARY KEY,

    user_id UUID NOT NULL,

    token_hash VARCHAR(255) NOT NULL UNIQUE,

    created_at TIMESTAMPTZ NOT NULL,

    expires_at TIMESTAMPTZ NOT NULL,

    revoked_at TIMESTAMPTZ,

    CONSTRAINT fk_refresh_tokens_user
        FOREIGN KEY (user_id)
            REFERENCES users(id)
);
