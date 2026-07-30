package memory_map.backend.auth.google;

import com.google.api.client.googleapis.auth.oauth2.GoogleIdToken;
import memory_map.backend.auth.domain.GoogleIdentity;

import java.io.IOException;
import java.security.GeneralSecurityException;
import java.util.Objects;

public class GoogleApiGoogleIdentityVerifier implements GoogleIdentityVerifier {

    private static final String VERIFICATION_FAILED_MESSAGE =
            "Google ID token verification failed";

    private final GoogleSdkTokenVerifier tokenVerifier;

    public GoogleApiGoogleIdentityVerifier(
            GoogleSdkTokenVerifier tokenVerifier
    ) {
        this.tokenVerifier = Objects.requireNonNull(tokenVerifier);
    }

    @Override
    public GoogleIdentity verify(String idToken) {

        if (idToken == null || idToken.isBlank()) {
            throw verificationFailed();
        }

        GoogleIdToken.Payload payload = verifiedPayload(idToken);
        String subject = payload.getSubject();

        if (subject == null || subject.isBlank()) {
            throw verificationFailed();
        }

        return new GoogleIdentity(
                subject,
                optionalStringClaim(payload, "name"),
                optionalStringClaim(payload, "picture")
        );
    }

    private GoogleIdToken.Payload verifiedPayload(String idToken) {
        try {
            GoogleIdToken.Payload payload = tokenVerifier.verify(idToken);

            if (payload == null) {
                throw verificationFailed();
            }

            return payload;
        } catch (IOException | GeneralSecurityException exception) {
            throw verificationFailed(exception);
        }
    }

    private static String optionalStringClaim(
            GoogleIdToken.Payload payload,
            String name
    ) {
        Object value = payload.get(name);

        if (value == null) {
            return null;
        }

        if (value instanceof String stringValue) {
            return stringValue;
        }

        throw verificationFailed();
    }

    private static GoogleIdentityVerificationException verificationFailed() {
        return new GoogleIdentityVerificationException(
                VERIFICATION_FAILED_MESSAGE
        );
    }

    private static GoogleIdentityVerificationException verificationFailed(
            Throwable cause
    ) {
        return new GoogleIdentityVerificationException(
                VERIFICATION_FAILED_MESSAGE,
                cause
        );
    }
}
