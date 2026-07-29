CREATE TABLE memories
(
    id UUID PRIMARY KEY,

    story_id UUID NOT NULL,

    created_by UUID NOT NULL,

    title VARCHAR(255) NOT NULL,

    description TEXT,

    place_name VARCHAR(255),

    location GEOGRAPHY(Point, 4326) NOT NULL,

    event_date DATE NOT NULL,

    created_at TIMESTAMPTZ NOT NULL,

    updated_at TIMESTAMPTZ NOT NULL,

    CONSTRAINT fk_memories_story
        FOREIGN KEY (story_id)
            REFERENCES stories(id),

    CONSTRAINT fk_memories_creator
        FOREIGN KEY (created_by)
            REFERENCES users(id)
);

CREATE INDEX idx_memories_story
    ON memories(story_id);

CREATE INDEX idx_memories_location
    ON memories
        USING GIST(location);
