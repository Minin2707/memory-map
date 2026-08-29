package memory_map.backend.account.api;

public class InvalidAvatarRequestException extends RuntimeException {

    private static final String MESSAGE = "Invalid avatar request";

    public InvalidAvatarRequestException(Throwable cause) {
        super(MESSAGE, cause);
    }
}
