package memory_map.backend.auth.login;

import memory_map.backend.auth.domain.GoogleIdentity;
import memory_map.backend.auth.google.GoogleIdentityVerificationException;
import memory_map.backend.auth.google.GoogleIdentityVerifier;

import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

public class DefaultGoogleLoginService implements GoogleLoginService {

    private static final String VERIFICATION_FAILED_MESSAGE =
            "Google ID token verification failed";

    private final GoogleIdentityVerifier googleIdentityVerifier;
    private final GoogleLoginTransaction googleLoginTransaction;

    public DefaultGoogleLoginService(
            GoogleIdentityVerifier googleIdentityVerifier,
            GoogleLoginTransaction googleLoginTransaction
    ) {
        this.googleIdentityVerifier = Objects.requireNonNull(
                googleIdentityVerifier,
                "googleIdentityVerifier must not be null"
        );
        this.googleLoginTransaction = Objects.requireNonNull(
                googleLoginTransaction,
                "googleLoginTransaction must not be null"
        );
    }

    @Override
    public GoogleLoginResult login(
            String googleIdToken,
            UUID newUserId,
            UUID newRefreshTokenId,
            Instant currentTime
    ) {
        if (googleIdToken == null || googleIdToken.isBlank()) {
            throw new GoogleIdentityVerificationException(
                    VERIFICATION_FAILED_MESSAGE
            );
        }

        Objects.requireNonNull(
                newUserId,
                "newUserId must not be null"
        );
        Objects.requireNonNull(
                newRefreshTokenId,
                "newRefreshTokenId must not be null"
        );
        Objects.requireNonNull(
                currentTime,
                "currentTime must not be null"
        );

        GoogleIdentity identity =
                googleIdentityVerifier.verify(googleIdToken);

        return googleLoginTransaction.login(
                identity,
                newUserId,
                newRefreshTokenId,
                currentTime
        );
    }
}
