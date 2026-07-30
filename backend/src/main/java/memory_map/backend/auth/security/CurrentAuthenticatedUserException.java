package memory_map.backend.auth.security;

public class CurrentAuthenticatedUserException
        extends RuntimeException {

    public CurrentAuthenticatedUserException(String message) {
        super(message);
    }

    public CurrentAuthenticatedUserException(
            String message,
            Throwable cause
    ) {
        super(message, cause);
    }
}
