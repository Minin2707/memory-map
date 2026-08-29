package memory_map.backend.account.application;

public class InvalidDisplayNameException extends RuntimeException {

    public InvalidDisplayNameException() {
        super("Invalid display name");
    }
}
