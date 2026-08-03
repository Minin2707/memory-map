package memory_map.backend.story.application;

import memory_map.backend.auth.domain.AuthenticatedUser;

import java.util.List;
import java.util.UUID;

public interface GetStoryParticipantsUseCase {

    /**
     * Returns participants of a Story available to the authenticated
     * participant.
     *
     * @throws StoryNotFoundException when the Story is missing or not available
     *         to the authenticated user
     */
    List<StoryParticipantView> getParticipants(
            AuthenticatedUser authenticatedUser,
            UUID storyId
    );

}
