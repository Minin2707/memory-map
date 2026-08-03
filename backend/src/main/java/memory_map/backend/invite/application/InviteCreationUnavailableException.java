package memory_map.backend.invite.application;

public final class InviteCreationUnavailableException extends RuntimeException {

    private static final String MESSAGE = "Invite could not be created";

    public InviteCreationUnavailableException() {
        super(MESSAGE);
    }
}
