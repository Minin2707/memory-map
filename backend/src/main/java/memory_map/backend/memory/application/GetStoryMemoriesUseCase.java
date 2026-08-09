package memory_map.backend.memory.application;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.memory.domain.Memory;
import memory_map.backend.story.application.StoryNotFoundException;

import java.util.List;
import java.util.UUID;

public interface GetStoryMemoriesUseCase {

    /**
     * Returns Memories from a Story available to the authenticated participant.
     *
     * @throws StoryNotFoundException when the Story is missing or not available
     *         to the authenticated user
     */
    List<Memory> getMemories(
            AuthenticatedUser authenticatedUser,
            UUID storyId
    );

}
