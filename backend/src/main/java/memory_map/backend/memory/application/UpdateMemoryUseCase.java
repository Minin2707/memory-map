package memory_map.backend.memory.application;

import memory_map.backend.memory.domain.Memory;

public interface UpdateMemoryUseCase {

    Memory updateMemory(UpdateMemoryCommand command);

}
