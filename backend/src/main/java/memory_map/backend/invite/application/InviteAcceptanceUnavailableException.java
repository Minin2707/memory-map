package memory_map.backend.invite.application;

public final class InviteAcceptanceUnavailableException
        extends RuntimeException {

    private static final String MESSAGE = "Invite could not be accepted";

    public InviteAcceptanceUnavailableException() {
        super(MESSAGE);
    }
}
