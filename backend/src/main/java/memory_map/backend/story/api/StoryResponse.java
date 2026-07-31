package memory_map.backend.story.api;

import memory_map.backend.story.domain.Story;

import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

public record StoryResponse(

        UUID id,

        String title,

        String description,

        Instant createdAt,

        Instant updatedAt

) {
    public static StoryResponse from(Story story) {
        Objects.requireNonNull(story, "story must not be null");

        return new StoryResponse(
                story.id(),
                story.title(),
                story.description(),
                story.createdAt(),
                story.updatedAt()
        );
    }
}
