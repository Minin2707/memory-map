package memory_map.backend.story.domain;

import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

public record Story(

        UUID id,

        UUID ownerId,

        String title,

        String description,

        Instant createdAt,

        Instant updatedAt

) {
    public Story {
        Objects.requireNonNull(id, "id must not be null");
        Objects.requireNonNull(ownerId, "ownerId must not be null");
        Objects.requireNonNull(createdAt, "createdAt must not be null");
        Objects.requireNonNull(updatedAt, "updatedAt must not be null");
    }
}
