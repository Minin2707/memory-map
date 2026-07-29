package memory_map.backend.memory.domain;

import java.time.Instant;
import java.time.LocalDate;
import java.util.Objects;
import java.util.UUID;

public record Memory(

        UUID id,

        UUID storyId,

        UUID createdBy,

        String title,

        String description,

        String placeName,

        double latitude,

        double longitude,

        LocalDate eventDate,

        Instant createdAt,

        Instant updatedAt

) {
    public Memory {
        Objects.requireNonNull(id, "id must not be null");
        Objects.requireNonNull(storyId, "storyId must not be null");
        Objects.requireNonNull(createdBy, "createdBy must not be null");
        Objects.requireNonNull(title, "title must not be null");
        Objects.requireNonNull(eventDate, "eventDate must not be null");
        Objects.requireNonNull(createdAt, "createdAt must not be null");
        Objects.requireNonNull(updatedAt, "updatedAt must not be null");

        if (title.isBlank()) {
            throw new IllegalArgumentException("title must not be blank");
        }

        if (!Double.isFinite(latitude) || latitude < -90.0 || latitude > 90.0) {
            throw new IllegalArgumentException("latitude must be between -90 and 90");
        }

        if (!Double.isFinite(longitude) || longitude < -180.0 || longitude > 180.0) {
            throw new IllegalArgumentException("longitude must be between -180 and 180");
        }
    }
}
