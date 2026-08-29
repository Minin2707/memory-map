package memory_map.backend.account.application;

public class AccountDeletionOwnershipConflictException
        extends RuntimeException {

    private static final String MESSAGE =
            "Transfer ownership of shared stories before deleting your profile.";

    public AccountDeletionOwnershipConflictException() {
        super(MESSAGE);
    }
}
