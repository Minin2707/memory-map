package memory_map.backend.account.application;

import memory_map.backend.media.storage.StorageKey;

import java.util.List;
import java.util.Objects;

public final class NoOpAccountDeletionMediaCleanupCoordinator
        implements AccountDeletionMediaCleanupCoordinator {

    @Override
    public void scheduleAfterCommitCleanup(List<StorageKey> storageKeys) {
        Objects.requireNonNull(storageKeys, "storageKeys must not be null");
    }
}
