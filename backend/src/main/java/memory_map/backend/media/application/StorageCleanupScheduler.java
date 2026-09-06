package memory_map.backend.media.application;

import memory_map.backend.media.storage.StorageKey;

import java.util.Collection;

public interface StorageCleanupScheduler {

    void schedule(Collection<StorageKey> storageKeys);
}
