package memory_map.backend.media.domain;

import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

public record MediaFile(

        UUID id,

        UUID memoryId,

        MediaType type,

        String displayStorageKey,

        long displayFileSize,

        String thumbnailStorageKey,

        long thumbnailFileSize,

        String mimeType,

        Instant createdAt

) {
    public MediaFile {
        Objects.requireNonNull(id, "id must not be null");
        Objects.requireNonNull(memoryId, "memoryId must not be null");
        Objects.requireNonNull(type, "type must not be null");
        Objects.requireNonNull(
                displayStorageKey,
                "displayStorageKey must not be null"
        );
        Objects.requireNonNull(
                thumbnailStorageKey,
                "thumbnailStorageKey must not be null"
        );
        Objects.requireNonNull(mimeType, "mimeType must not be null");
        Objects.requireNonNull(createdAt, "createdAt must not be null");

        if (displayStorageKey.isBlank()) {
            throw new IllegalArgumentException("displayStorageKey must not be blank");
        }

        if (thumbnailStorageKey.isBlank()) {
            throw new IllegalArgumentException("thumbnailStorageKey must not be blank");
        }

        if (displayStorageKey.equals(thumbnailStorageKey)) {
            throw new IllegalArgumentException(
                    "displayStorageKey and thumbnailStorageKey must differ"
            );
        }

        if (displayFileSize <= 0) {
            throw new IllegalArgumentException("displayFileSize must be positive");
        }

        if (thumbnailFileSize <= 0) {
            throw new IllegalArgumentException("thumbnailFileSize must be positive");
        }

        if (mimeType.isBlank()) {
            throw new IllegalArgumentException("mimeType must not be blank");
        }
    }

    @Override
    public String toString() {
        return "MediaFile[type=%s, hasDisplay=true, hasThumbnail=true, hasMimeType=true]"
                .formatted(type);
    }
}
