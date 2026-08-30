package memory_map.backend.story.domain;

import java.time.Instant;
import java.util.Objects;

public record StoryCoverMetadata(

        String displayStorageKey,

        long displayFileSize,

        String thumbnailStorageKey,

        long thumbnailFileSize,

        String mimeType,

        Instant updatedAt

) {
    public StoryCoverMetadata {
        Objects.requireNonNull(
                displayStorageKey,
                "displayStorageKey must not be null"
        );
        Objects.requireNonNull(
                thumbnailStorageKey,
                "thumbnailStorageKey must not be null"
        );
        Objects.requireNonNull(mimeType, "mimeType must not be null");
        Objects.requireNonNull(updatedAt, "updatedAt must not be null");

        if (displayStorageKey.isBlank()) {
            throw new IllegalArgumentException(
                    "displayStorageKey must not be blank"
            );
        }

        if (thumbnailStorageKey.isBlank()) {
            throw new IllegalArgumentException(
                    "thumbnailStorageKey must not be blank"
            );
        }

        if (displayStorageKey.equals(thumbnailStorageKey)) {
            throw new IllegalArgumentException(
                    "displayStorageKey and thumbnailStorageKey must differ"
            );
        }

        if (displayFileSize <= 0) {
            throw new IllegalArgumentException(
                    "displayFileSize must be positive"
            );
        }

        if (thumbnailFileSize <= 0) {
            throw new IllegalArgumentException(
                    "thumbnailFileSize must be positive"
            );
        }

        if (mimeType.isBlank()) {
            throw new IllegalArgumentException("mimeType must not be blank");
        }
    }

    @Override
    public String toString() {
        return "StoryCoverMetadata[hasDisplay=true, hasThumbnail=true, hasMimeType=true]";
    }
}
