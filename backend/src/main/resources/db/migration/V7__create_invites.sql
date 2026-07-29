CREATE TABLE invites
(
    id UUID PRIMARY KEY,

    story_id UUID NOT NULL,

    token_hash VARCHAR(255) NOT NULL UNIQUE,

    created_by UUID NOT NULL,

    created_at TIMESTAMPTZ NOT NULL,

    expires_at TIMESTAMPTZ NOT NULL,

    used_at TIMESTAMPTZ,

    CONSTRAINT fk_invites_story
        FOREIGN KEY (story_id)
            REFERENCES stories(id),

    CONSTRAINT fk_invites_creator
        FOREIGN KEY (created_by)
            REFERENCES users(id)
);
