package memory_map.backend.story.repository;

import java.util.List;
import java.util.UUID;

public interface StoryDeletionRepository {

    List<StoryDeletionMediaStorageKeys> findMediaStorageKeysByStoryId(
            UUID storyId
    );

    int deleteInvitesByStoryId(UUID storyId);

    int deleteMemoriesByStoryId(UUID storyId);

    boolean deleteStoryById(UUID storyId);

}
