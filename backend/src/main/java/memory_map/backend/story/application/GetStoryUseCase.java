package memory_map.backend.story.application;

import memory_map.backend.auth.domain.AuthenticatedUser;

import java.util.UUID;

public interface GetStoryUseCase {

    /**
     * Returns a Story available to the authenticated participant.
     *
     * @throws StoryNotFoundException when the Story is missing or not available
     *         to the authenticated user
     */
    UserStory getStory(
            AuthenticatedUser authenticatedUser,
            UUID storyId
    );

}
