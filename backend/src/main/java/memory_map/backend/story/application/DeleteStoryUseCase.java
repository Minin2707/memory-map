package memory_map.backend.story.application;

public interface DeleteStoryUseCase {

    /**
     * Deletes an entire Story graph.
     *
     * @throws StoryNotFoundException when the Story is missing or the delete
     *         operation is not available to the authenticated user
     */
    void deleteStory(DeleteStoryCommand command);

}
