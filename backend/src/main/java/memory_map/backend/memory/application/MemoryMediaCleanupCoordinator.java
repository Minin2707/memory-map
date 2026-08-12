package memory_map.backend.memory.application;

import java.util.UUID;

public interface MemoryMediaCleanupCoordinator {

    void prepareAfterCommitCleanup(UUID memoryId);
}
