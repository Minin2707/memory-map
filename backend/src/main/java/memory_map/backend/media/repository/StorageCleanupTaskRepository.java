package memory_map.backend.media.repository;

import memory_map.backend.media.application.StorageCleanupTask;
import memory_map.backend.media.storage.StorageKey;

import java.time.Instant;
import java.util.Collection;
import java.util.List;
import java.util.UUID;

public interface StorageCleanupTaskRepository {

    void enqueue(StorageKey storageKey, Instant currentTime);

    void enqueueAll(Collection<StorageKey> storageKeys, Instant currentTime);

    List<StorageCleanupTask> findDueForUpdate(
            Instant currentTime,
            int limit
    );

    void markFailed(UUID taskId, Instant nextAttemptAt);

    void delete(UUID taskId);
}
