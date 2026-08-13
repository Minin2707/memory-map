package memory_map.backend.memory.repository;

import memory_map.backend.memory.application.MemoryReadModel;
import memory_map.backend.memory.application.StoryMemoriesView;

import java.util.Optional;
import java.util.UUID;

public interface MemoryReadRepository {

    Optional<StoryMemoriesView> findByStoryIdAndRequesterUserId(
            UUID storyId,
            UUID requesterUserId
    );

    Optional<MemoryReadModel> findByIdAndRequesterUserId(
            UUID memoryId,
            UUID requesterUserId
    );

}
