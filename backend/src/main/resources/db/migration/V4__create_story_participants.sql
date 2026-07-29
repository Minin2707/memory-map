CREATE TABLE story_participants
(
    story_id  UUID                     NOT NULL,
    user_id   UUID                     NOT NULL,
    role      VARCHAR(20)              NOT NULL,
    joined_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_story_participants
        PRIMARY KEY (story_id, user_id),

    CONSTRAINT fk_story_participants_story
        FOREIGN KEY (story_id)
            REFERENCES stories (id)
            ON DELETE CASCADE,

    CONSTRAINT fk_story_participants_user
        FOREIGN KEY (user_id)
            REFERENCES users (id)
            ON DELETE CASCADE
);

CREATE INDEX idx_story_participants_user_id
    ON story_participants (user_id);