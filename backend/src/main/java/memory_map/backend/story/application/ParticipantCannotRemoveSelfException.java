package memory_map.backend.story.application;

public class ParticipantCannotRemoveSelfException extends RuntimeException {

    private static final String MESSAGE =
            "Use the leave story operation to remove yourself";

    public ParticipantCannotRemoveSelfException() {
        super(MESSAGE);
    }
}
