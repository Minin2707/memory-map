package memory_map.backend.user.domain;

import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

public record User(

        UUID id,

        String googleSubject,

        String displayName,

        String avatarUrl,

        Instant createdAt,

        Instant updatedAt

) {
    public User {
        Objects.requireNonNull(id, "id must not be null");
        Objects.requireNonNull(googleSubject, "googleSubject must not be null");
        Objects.requireNonNull(displayName, "displayName must not be null");
        Objects.requireNonNull(createdAt, "createdAt must not be null");
        Objects.requireNonNull(updatedAt, "updatedAt must not be null");

        if (googleSubject.isBlank()) {
            throw new IllegalArgumentException("googleSubject must not be blank");
        }

        if (displayName.isBlank()) {
            throw new IllegalArgumentException("displayName must not be blank");
        }
    }
}
