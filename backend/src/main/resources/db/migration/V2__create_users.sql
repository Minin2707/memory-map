CREATE TABLE users
(
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    google_subject  VARCHAR(255) NOT NULL,

    display_name    VARCHAR(255) NOT NULL,

    avatar_url      TEXT,

    created_at      TIMESTAMPTZ  NOT NULL,

    updated_at      TIMESTAMPTZ  NOT NULL,

    CONSTRAINT uk_users_google_subject
        UNIQUE (google_subject)
);