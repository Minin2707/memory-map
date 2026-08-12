package memory_map.backend.memory.application;

import memory_map.backend.media.application.TransactionCommitCoordinator;
import memory_map.backend.media.domain.MediaFile;
import memory_map.backend.media.repository.MediaFileRepository;
import memory_map.backend.media.storage.StorageKey;
import memory_map.backend.media.storage.StorageService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.ArrayList;
import java.util.List;
import java.util.Objects;
import java.util.UUID;

public final class StorageBackedMemoryMediaCleanupCoordinator
        implements MemoryMediaCleanupCoordinator {

    private static final Logger LOGGER = LoggerFactory.getLogger(
            StorageBackedMemoryMediaCleanupCoordinator.class
    );

    private final MediaFileRepository mediaFileRepository;
    private final StorageService storageService;
    private final TransactionCommitCoordinator commitCoordinator;

    public StorageBackedMemoryMediaCleanupCoordinator(
            MediaFileRepository mediaFileRepository,
            StorageService storageService,
            TransactionCommitCoordinator commitCoordinator
    ) {
        this.mediaFileRepository = Objects.requireNonNull(
                mediaFileRepository,
                "mediaFileRepository must not be null"
        );
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
    public void prepareAfterCommitCleanup(UUID memoryId) {
        Objects.requireNonNull(memoryId, "memoryId must not be null");

        List<StorageKey> storageKeys = storageKeysFor(memoryId);

        if (storageKeys.isEmpty()) {
            return;
        }

        commitCoordinator.onCommit(() -> cleanupStorage(storageKeys));
    }

    private List<StorageKey> storageKeysFor(UUID memoryId) {
        List<StorageKey> storageKeys = new ArrayList<>();

        for (MediaFile mediaFile : mediaFileRepository.findByMemoryId(memoryId)) {
            storageKeys.add(new StorageKey(mediaFile.thumbnailStorageKey()));
            storageKeys.add(new StorageKey(mediaFile.displayStorageKey()));
        }

        return List.copyOf(storageKeys);
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
                    "Media storage cleanup failed after metadata deletion: {}",
                    exception.getClass().getName()
            );
        }
    }
}
