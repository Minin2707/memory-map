package memory_map.backend.account.application;

import memory_map.backend.media.application.TransactionCommitCoordinator;
import memory_map.backend.media.storage.StorageKey;
import memory_map.backend.media.storage.StorageService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.List;
import java.util.Objects;

public final class StorageBackedAccountDeletionMediaCleanupCoordinator
        implements AccountDeletionMediaCleanupCoordinator {

    private static final Logger LOGGER = LoggerFactory.getLogger(
            StorageBackedAccountDeletionMediaCleanupCoordinator.class
    );

    private final StorageService storageService;
    private final TransactionCommitCoordinator commitCoordinator;

    public StorageBackedAccountDeletionMediaCleanupCoordinator(
            StorageService storageService,
            TransactionCommitCoordinator commitCoordinator
    ) {
        this.storageService = Objects.requireNonNull(
                storageService,
                "storageService must not be null"
        );
        this.commitCoordinator = Objects.requireNonNull(
                commitCoordinator,
                "commitCoordinator must not be null"
        );
    }

    @Override
    public void scheduleAfterCommitCleanup(List<StorageKey> storageKeys) {
        Objects.requireNonNull(storageKeys, "storageKeys must not be null");

        if (storageKeys.isEmpty()) {
            return;
        }

        commitCoordinator.onCommit(() -> cleanupStorage(storageKeys));
    }

    private void cleanupStorage(List<StorageKey> storageKeys) {
        for (StorageKey storageKey : storageKeys) {
            cleanupQuietly(storageKey);
        }
    }

    private void cleanupQuietly(StorageKey storageKey) {
        try {
            storageService.delete(storageKey);
        } catch (RuntimeException exception) {
            LOGGER.warn(
                    "Media storage cleanup failed after account deletion: {}",
                    exception.getClass().getName()
            );
        }
    }
}
