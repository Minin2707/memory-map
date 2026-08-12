package memory_map.backend.memory.application;

import memory_map.backend.media.repository.MediaFileRepository;

import java.util.Objects;
import java.util.UUID;

public final class StorageUnavailableMemoryMediaCleanupCoordinator
        implements MemoryMediaCleanupCoordinator {

    private final MediaFileRepository mediaFileRepository;

    public StorageUnavailableMemoryMediaCleanupCoordinator(
            MediaFileRepository mediaFileRepository
    ) {
        this.mediaFileRepository = Objects.requireNonNull(
                mediaFileRepository,
                "mediaFileRepository must not be null"
        );
    }

    @Override
    public void prepareAfterCommitCleanup(UUID memoryId) {
        Objects.requireNonNull(memoryId, "memoryId must not be null");

        if (mediaFileRepository.findByMemoryId(memoryId).isEmpty()) {
            return;
        }

        throw new IllegalStateException(
                "Media storage cleanup is unavailable"
        );
    }
}
