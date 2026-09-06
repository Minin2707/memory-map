package memory_map.backend.media.application;

import memory_map.backend.media.storage.StorageKey;

import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

public record StorageCleanupTask(
        UUID id,
        StorageKey storageKey,
        Instant createdAt,
        Instant nextAttemptAt,
        int attemptCount
) {

    public StorageCleanupTask {
        Objects.requireNonNull(id, "id must not be null");
        Objects.requireNonNull(storageKey, "storageKey must not be null");
        Objects.requireNonNull(createdAt, "createdAt must not be null");
        Objects.requireNonNull(nextAttemptAt, "nextAttemptAt must not be null");

        if (attemptCount < 0) {
            throw new IllegalArgumentException(
                    "attemptCount must not be negative"
            );
        }
    }

    @Override
    public String toString() {
        return (
                "StorageCleanupTask[id=%s, hasStorageKey=true, "
                        + "createdAt=%s, nextAttemptAt=%s, attemptCount=%d]"
        ).formatted(
                id,
                createdAt,
                nextAttemptAt,
                attemptCount
        );
    }
}
