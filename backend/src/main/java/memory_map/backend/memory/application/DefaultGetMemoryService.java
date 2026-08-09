package memory_map.backend.memory.application;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.memory.domain.Memory;
import memory_map.backend.memory.repository.MemoryReadRepository;

import java.util.Objects;
import java.util.UUID;

public class DefaultGetMemoryService implements GetMemoryUseCase {

    private final MemoryReadRepository repository;

    public DefaultGetMemoryService(
            MemoryReadRepository repository
    ) {
        this.repository = Objects.requireNonNull(
                repository,
                "repository must not be null"
        );
    }

    @Override
    public Memory getMemory(
            AuthenticatedUser authenticatedUser,
            UUID memoryId
    ) {
        Objects.requireNonNull(
                authenticatedUser,
                "authenticatedUser must not be null"
        );
        Objects.requireNonNull(memoryId, "memoryId must not be null");

        return repository.findByIdAndRequesterUserId(
                memoryId,
                authenticatedUser.userId()
        ).orElseThrow(MemoryNotFoundException::new);
    }
}
