package memory_map.backend.auth.jwt;

public class AccessTokenVerificationException extends RuntimeException {

    public AccessTokenVerificationException(String message) {
        super(message);
    }

    public AccessTokenVerificationException(
            String message,
            Throwable cause
    ) {
        super(message, cause);
    }
}
