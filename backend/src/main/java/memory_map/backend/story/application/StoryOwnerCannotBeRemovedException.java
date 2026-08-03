package memory_map.backend.story.application;

public class StoryOwnerCannotBeRemovedException extends RuntimeException {

    private static final String MESSAGE = "A story owner cannot be removed";

    public StoryOwnerCannotBeRemovedException() {
        super(MESSAGE);
    }
}
