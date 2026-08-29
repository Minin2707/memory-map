package memory_map.backend.account.application;

import memory_map.backend.media.storage.StorageKey;

import java.util.List;

public interface AccountDeletionMediaCleanupCoordinator {

    void scheduleAfterCommitCleanup(List<StorageKey> storageKeys);
}
