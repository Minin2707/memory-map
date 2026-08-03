package memory_map.backend.story.application;

public interface LeaveStoryUseCase {

    /**
     * Removes the authenticated user's own participant record from a Story.
     *
     * @throws StoryNotFoundException when the Story is missing or not
     *         available to the authenticated user
     * @throws LastStoryOwnerCannotLeaveException when the authenticated
     *         participant is the last OWNER of the Story
     */
    void leaveStory(LeaveStoryCommand command);

}
