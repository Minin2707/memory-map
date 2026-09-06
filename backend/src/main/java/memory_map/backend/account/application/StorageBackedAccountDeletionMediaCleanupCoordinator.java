package memory_map.backend.account.application;

import memory_map.backend.media.application.StorageCleanupScheduler;
import memory_map.backend.media.storage.StorageKey;

import java.util.List;
import java.util.Objects;

public final class StorageBackedAccountDeletionMediaCleanupCoordinator
        implements AccountDeletionMediaCleanupCoordinator {

    private final StorageCleanupScheduler cleanupScheduler;

    public StorageBackedAccountDeletionMediaCleanupCoordinator(
            StorageCleanupScheduler cleanupScheduler
    ) {
        this.cleanupScheduler = Objects.requireNonNull(
                cleanupScheduler,
                "cleanupScheduler must not be null"
        );
    }

    @Override
    public void scheduleCleanup(List<StorageKey> storageKeys) {
        Objects.requireNonNull(storageKeys, "storageKeys must not be null");
        cleanupScheduler.schedule(storageKeys);
    }
}
