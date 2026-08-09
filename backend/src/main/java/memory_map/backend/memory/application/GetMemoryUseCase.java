package memory_map.backend.memory.application;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.memory.domain.Memory;

import java.util.UUID;

public interface GetMemoryUseCase {

    /**
     * Returns a Memory available through the authenticated participant's Story.
     *
     * @throws MemoryNotFoundException when the Memory is missing or not
     *         available to the authenticated user
     */
    Memory getMemory(
            AuthenticatedUser authenticatedUser,
            UUID memoryId
    );

}
