package memory_map.backend.account.application;

public class AccountDeletionUnavailableException
        extends RuntimeException {

    private static final String MESSAGE =
            "Profile could not be deleted";

    public AccountDeletionUnavailableException() {
        super(MESSAGE);
    }
}
