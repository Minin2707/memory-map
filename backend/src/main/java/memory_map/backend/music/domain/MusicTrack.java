package memory_map.backend.music.domain;

import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

public record MusicTrack(

        UUID id,

        String title,

        String artist,

        int durationSeconds,

        MusicTrackStatus status,

        int sortOrder,

        String storageKey,

        String mimeType,

        long fileSize,

        Instant createdAt,

        Instant updatedAt

) {
    public MusicTrack {
        Objects.requireNonNull(id, "id must not be null");
        Objects.requireNonNull(title, "title must not be null");
        Objects.requireNonNull(artist, "artist must not be null");
        Objects.requireNonNull(status, "status must not be null");
        Objects.requireNonNull(storageKey, "storageKey must not be null");
        Objects.requireNonNull(mimeType, "mimeType must not be null");
        Objects.requireNonNull(createdAt, "createdAt must not be null");
        Objects.requireNonNull(updatedAt, "updatedAt must not be null");

        if (title.isBlank()) {
            throw new IllegalArgumentException("title must not be blank");
        }

        if (artist.isBlank()) {
            throw new IllegalArgumentException("artist must not be blank");
        }

        if (durationSeconds <= 0) {
            throw new IllegalArgumentException(
                    "durationSeconds must be positive"
            );
        }

        if (sortOrder < 0) {
            throw new IllegalArgumentException(
                    "sortOrder must not be negative"
            );
        }

        if (storageKey.isBlank()) {
            throw new IllegalArgumentException("storageKey must not be blank");
        }

        if (mimeType.isBlank()) {
            throw new IllegalArgumentException("mimeType must not be blank");
        }

        if (fileSize <= 0) {
            throw new IllegalArgumentException("fileSize must be positive");
        }

        if (updatedAt.isBefore(createdAt)) {
            throw new IllegalArgumentException(
                    "updatedAt must not be before createdAt"
            );
        }
    }

    @Override
    public String toString() {
        return (
                "MusicTrack[id=%s, title=%s, artist=%s, "
                        + "durationSeconds=%d, status=%s, sortOrder=%d, "
                        + "createdAt=%s, updatedAt=%s]"
        )
                .formatted(
                        id,
                        title,
                        artist,
                        durationSeconds,
                        status,
                        sortOrder,
                        createdAt,
                        updatedAt
                );
    }
}
