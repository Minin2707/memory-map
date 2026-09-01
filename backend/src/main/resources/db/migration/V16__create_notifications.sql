CREATE TABLE notifications
(
    id UUID PRIMARY KEY,

    recipient_user_id UUID NOT NULL,

    type VARCHAR(40) NOT NULL,

    actor_user_id UUID NOT NULL,

    story_id UUID NULL,

    memory_id UUID NULL,

    created_at TIMESTAMPTZ NOT NULL,

    read_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_notifications_recipient_user
        FOREIGN KEY (recipient_user_id)
            REFERENCES users(id)
            ON DELETE RESTRICT,

    CONSTRAINT fk_notifications_actor_user
        FOREIGN KEY (actor_user_id)
            REFERENCES users(id)
            ON DELETE RESTRICT,

    CONSTRAINT fk_notifications_story
        FOREIGN KEY (story_id)
            REFERENCES stories(id)
            ON DELETE SET NULL,

    CONSTRAINT fk_notifications_memory
        FOREIGN KEY (memory_id)
            REFERENCES memories(id)
            ON DELETE SET NULL,

    CONSTRAINT ck_notifications_type
        CHECK (type IN (
            'PARTICIPANT_JOINED',
            'MEMORY_CREATED',
            'PHOTOS_ADDED'
        )),

    CONSTRAINT ck_notifications_recipient_not_actor
        CHECK (recipient_user_id <> actor_user_id),

    CONSTRAINT ck_notifications_participant_joined_memory_absent
        CHECK (type <> 'PARTICIPANT_JOINED' OR memory_id IS NULL),

    CONSTRAINT ck_notifications_read_not_before_created
        CHECK (read_at IS NULL OR read_at >= created_at)
);

CREATE INDEX idx_notifications_recipient_created_at
    ON notifications(recipient_user_id, created_at DESC, id DESC);

CREATE INDEX idx_notifications_recipient_unread
    ON notifications(recipient_user_id)
    WHERE read_at IS NULL;
