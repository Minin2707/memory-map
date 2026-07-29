package memory_map.backend.memory.repository;

import memory_map.backend.memory.domain.Memory;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface MemoryRepository {

    Optional<Memory> findById(UUID id);

    List<Memory> findByStoryId(UUID storyId);

    void save(Memory memory);

    void update(Memory memory);

    void delete(UUID id);

}
