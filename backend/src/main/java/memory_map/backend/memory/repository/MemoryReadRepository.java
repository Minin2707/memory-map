package memory_map.backend.memory.repository;

import memory_map.backend.memory.application.StoryMemoriesView;
import memory_map.backend.memory.domain.Memory;

import java.util.Optional;
import java.util.UUID;

public interface MemoryReadRepository {

    Optional<StoryMemoriesView> findByStoryIdAndRequesterUserId(
            UUID storyId,
            UUID requesterUserId
    );

    Optional<Memory> findByIdAndRequesterUserId(
            UUID memoryId,
            UUID requesterUserId
    );

}
