package memory_map.backend.memory.application;

import memory_map.backend.media.application.StorageCleanupScheduler;
import memory_map.backend.media.domain.MediaFile;
import memory_map.backend.media.repository.MediaFileRepository;
import memory_map.backend.media.storage.StorageKey;

import java.util.ArrayList;
import java.util.List;
import java.util.Objects;
import java.util.UUID;

public final class StorageBackedMemoryMediaCleanupCoordinator
        implements MemoryMediaCleanupCoordinator {

    private final MediaFileRepository mediaFileRepository;
    private final StorageCleanupScheduler cleanupScheduler;

    public StorageBackedMemoryMediaCleanupCoordinator(
            MediaFileRepository mediaFileRepository,
            StorageCleanupScheduler cleanupScheduler
    ) {
        this.mediaFileRepository = Objects.requireNonNull(
                mediaFileRepository,
                "mediaFileRepository must not be null"
        );
        this.cleanupScheduler = Objects.requireNonNull(
                cleanupScheduler,
                "cleanupScheduler must not be null"
        );
    }

    @Override
    public void scheduleCleanup(UUID memoryId) {
        Objects.requireNonNull(memoryId, "memoryId must not be null");

        List<StorageKey> storageKeys = storageKeysFor(memoryId);

        cleanupScheduler.schedule(storageKeys);
    }

    private List<StorageKey> storageKeysFor(UUID memoryId) {
        List<StorageKey> storageKeys = new ArrayList<>();

        for (MediaFile mediaFile : mediaFileRepository.findByMemoryId(memoryId)) {
            storageKeys.add(new StorageKey(mediaFile.thumbnailStorageKey()));
            storageKeys.add(new StorageKey(mediaFile.displayStorageKey()));
        }

        return List.copyOf(storageKeys);
    }
}
