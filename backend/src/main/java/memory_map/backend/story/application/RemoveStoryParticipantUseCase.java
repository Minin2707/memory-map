package memory_map.backend.story.application;

public interface RemoveStoryParticipantUseCase {

    /**
     * Removes another participant from a Story.
     *
     * @throws StoryNotFoundException when the Story or participant removal
     *         operation is not available to the authenticated user
     * @throws StoryOwnerCannotBeRemovedException when the target participant
     *         is an OWNER
     * @throws ParticipantCannotRemoveSelfException when the authenticated
     *         user targets their own participant record
     */
    void removeParticipant(RemoveStoryParticipantCommand command);

}
