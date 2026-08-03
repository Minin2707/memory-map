package memory_map.backend.story.application;

public class LastStoryOwnerCannotLeaveException extends RuntimeException {

    private static final String MESSAGE =
            "The last owner cannot leave the story";

    public LastStoryOwnerCannotLeaveException() {
        super(MESSAGE);
    }
}
