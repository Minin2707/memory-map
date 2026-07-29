package memory_map.backend.media.domain;

import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

public record MediaFile(

        UUID id,

        UUID memoryId,

        MediaType type,

        Long fileSize,

        String mimeType,

        String storageKey,

        Instant createdAt

) {
    public MediaFile {
        Objects.requireNonNull(id, "id must not be null");
        Objects.requireNonNull(memoryId, "memoryId must not be null");
        Objects.requireNonNull(type, "type must not be null");
        Objects.requireNonNull(storageKey, "storageKey must not be null");
        Objects.requireNonNull(createdAt, "createdAt must not be null");

        if (storageKey.isBlank()) {
            throw new IllegalArgumentException("storageKey must not be blank");
        }

        if (fileSize != null && fileSize < 0) {
            throw new IllegalArgumentException("fileSize must not be negative");
        }
    }
}
