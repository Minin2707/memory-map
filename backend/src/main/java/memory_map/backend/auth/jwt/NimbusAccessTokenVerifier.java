package memory_map.backend.auth.jwt;

import memory_map.backend.auth.domain.AuthenticatedUser;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtException;

import java.util.Objects;
import java.util.UUID;

public class NimbusAccessTokenVerifier implements AccessTokenVerifier {

    private static final String VERIFICATION_FAILED_MESSAGE =
            "Access token verification failed";

    private final JwtDecoder jwtDecoder;

    public NimbusAccessTokenVerifier(JwtDecoder jwtDecoder) {
        this.jwtDecoder = Objects.requireNonNull(jwtDecoder);
    }

    @Override
    public AuthenticatedUser verify(String accessToken) {

        if (accessToken == null || accessToken.isBlank()) {
            throw verificationFailed();
        }

        Jwt jwt = decode(accessToken);
        String subject = jwt.getSubject();

        if (subject == null || subject.isBlank()) {
            throw verificationFailed();
        }

        try {
            UUID userId = UUID.fromString(subject);

            return new AuthenticatedUser(userId);
        } catch (IllegalArgumentException exception) {
            throw verificationFailed(exception);
        }
    }

    private Jwt decode(String accessToken) {
        try {
            return jwtDecoder.decode(accessToken);
        } catch (JwtException exception) {
            throw verificationFailed(exception);
        }
    }

    private static AccessTokenVerificationException verificationFailed() {
        return new AccessTokenVerificationException(
                VERIFICATION_FAILED_MESSAGE
        );
    }

    private static AccessTokenVerificationException verificationFailed(
            Throwable cause
    ) {
        return new AccessTokenVerificationException(
                VERIFICATION_FAILED_MESSAGE,
                cause
        );
    }
}
