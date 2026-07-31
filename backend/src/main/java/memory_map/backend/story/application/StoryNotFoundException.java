package memory_map.backend.story.application;

public class StoryNotFoundException extends RuntimeException {

    private static final String MESSAGE = "Story was not found";

    public StoryNotFoundException() {
        super(MESSAGE);
    }
}
