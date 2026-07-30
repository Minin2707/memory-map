package memory_map.backend.auth.google;

public class GoogleIdentityVerificationException extends RuntimeException {

    public GoogleIdentityVerificationException(String message) {
        super(message);
    }

    public GoogleIdentityVerificationException(
            String message,
            Throwable cause
    ) {
        super(message, cause);
    }
}
