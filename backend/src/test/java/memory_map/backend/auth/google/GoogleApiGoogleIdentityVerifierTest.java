package memory_map.backend.auth.google;

import com.google.api.client.googleapis.auth.oauth2.GoogleIdToken;
import memory_map.backend.auth.domain.GoogleIdentity;
import org.junit.jupiter.api.Test;

import java.io.IOException;
import java.security.GeneralSecurityException;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class GoogleApiGoogleIdentityVerifierTest {

    private static final String FAILURE_MESSAGE =
            "Google ID token verification failed";

    @Test
    void shouldReturnGoogleIdentityForVerifiedToken() {

        GoogleIdToken.Payload payload = payloadWithSubject("subject-123");
        payload.set("name", "Konstantin");
        payload.set("picture", "https://example.com/avatar.png");
        FakeGoogleSdkTokenVerifier tokenVerifier =
                FakeGoogleSdkTokenVerifier.returning(payload);
        GoogleApiGoogleIdentityVerifier verifier =
                new GoogleApiGoogleIdentityVerifier(tokenVerifier);

        GoogleIdentity identity = verifier.verify("raw-google-id-token");

        assertThat(identity.subject()).isEqualTo("subject-123");
        assertThat(identity.displayName()).isEqualTo("Konstantin");
        assertThat(identity.avatarUrl())
                .isEqualTo("https://example.com/avatar.png");
        assertThat(tokenVerifier.verifiedToken)
                .isEqualTo("raw-google-id-token");
    }

    @Test
    void shouldAllowMissingDisplayName() {

        GoogleIdToken.Payload payload = payloadWithSubject("subject-123");
        payload.set("picture", "https://example.com/avatar.png");
        GoogleApiGoogleIdentityVerifier verifier =
                verifierReturning(payload);

        GoogleIdentity identity = verifier.verify("raw-google-id-token");

        assertThat(identity.displayName()).isNull();
        assertThat(identity.avatarUrl())
                .isEqualTo("https://example.com/avatar.png");
    }

    @Test
    void shouldAllowMissingAvatarUrl() {

        GoogleIdToken.Payload payload = payloadWithSubject("subject-123");
        payload.set("name", "Konstantin");
        GoogleApiGoogleIdentityVerifier verifier =
                verifierReturning(payload);

        GoogleIdentity identity = verifier.verify("raw-google-id-token");

        assertThat(identity.displayName()).isEqualTo("Konstantin");
        assertThat(identity.avatarUrl()).isNull();
    }

    @Test
    void shouldRejectNullToken() {

        GoogleApiGoogleIdentityVerifier verifier =
                verifierReturning(payloadWithSubject("subject-123"));

        assertVerificationFailure(() -> verifier.verify(null), null);
    }

    @Test
    void shouldRejectEmptyToken() {

        GoogleApiGoogleIdentityVerifier verifier =
                verifierReturning(payloadWithSubject("subject-123"));

        assertVerificationFailure(() -> verifier.verify(""), "");
    }

    @Test
    void shouldRejectWhitespaceToken() {

        GoogleApiGoogleIdentityVerifier verifier =
                verifierReturning(payloadWithSubject("subject-123"));

        assertVerificationFailure(() -> verifier.verify("   "), "   ");
    }

    @Test
    void shouldRejectInvalidTokenWhenSdkReturnsNoPayload() {

        GoogleApiGoogleIdentityVerifier verifier = verifierReturning(null);

        assertVerificationFailure(
                () -> verifier.verify("raw-google-id-token"),
                "raw-google-id-token"
        );
    }

    @Test
    void shouldRejectPayloadWithoutSubject() {

        GoogleApiGoogleIdentityVerifier verifier =
                verifierReturning(new GoogleIdToken.Payload());

        assertVerificationFailure(
                () -> verifier.verify("raw-google-id-token"),
                "raw-google-id-token"
        );
    }

    @Test
    void shouldRejectPayloadWithBlankSubject() {

        GoogleApiGoogleIdentityVerifier verifier =
                verifierReturning(payloadWithSubject("   "));

        assertVerificationFailure(
                () -> verifier.verify("raw-google-id-token"),
                "raw-google-id-token"
        );
    }

    @Test
    void shouldWrapSdkIOException() {

        IOException cause = new IOException("public keys unavailable");
        GoogleApiGoogleIdentityVerifier verifier =
                new GoogleApiGoogleIdentityVerifier(
                        FakeGoogleSdkTokenVerifier.throwing(cause)
                );

        assertThatThrownBy(() -> verifier.verify("raw-google-id-token"))
                .isInstanceOf(GoogleIdentityVerificationException.class)
                .hasMessage(FAILURE_MESSAGE)
                .hasCause(cause)
                .satisfies(throwable -> assertThat(throwable.getMessage())
                        .doesNotContain("raw-google-id-token"));
    }

    @Test
    void shouldWrapSdkGeneralSecurityException() {

        GeneralSecurityException cause =
                new GeneralSecurityException("invalid signature");
        GoogleApiGoogleIdentityVerifier verifier =
                new GoogleApiGoogleIdentityVerifier(
                        FakeGoogleSdkTokenVerifier.throwing(cause)
                );

        assertThatThrownBy(() -> verifier.verify("raw-google-id-token"))
                .isInstanceOf(GoogleIdentityVerificationException.class)
                .hasMessage(FAILURE_MESSAGE)
                .hasCause(cause)
                .satisfies(throwable -> assertThat(throwable.getMessage())
                        .doesNotContain("raw-google-id-token"));
    }

    @Test
    void shouldRejectNonStringOptionalClaim() {

        GoogleIdToken.Payload payload = payloadWithSubject("subject-123");
        payload.set("name", 123);
        GoogleApiGoogleIdentityVerifier verifier =
                verifierReturning(payload);

        assertVerificationFailure(
                () -> verifier.verify("raw-google-id-token"),
                "raw-google-id-token"
        );
    }

    private static GoogleApiGoogleIdentityVerifier verifierReturning(
            GoogleIdToken.Payload payload
    ) {
        return new GoogleApiGoogleIdentityVerifier(
                FakeGoogleSdkTokenVerifier.returning(payload)
        );
    }

    private static GoogleIdToken.Payload payloadWithSubject(String subject) {
        return new GoogleIdToken.Payload()
                .setSubject(subject);
    }

    private static void assertVerificationFailure(
            ThrowingAction action,
            String rawToken
    ) {
        assertThatThrownBy(action::run)
                .isInstanceOf(GoogleIdentityVerificationException.class)
                .hasMessage(FAILURE_MESSAGE)
                .satisfies(throwable -> {
                    if (rawToken != null && !rawToken.isEmpty()) {
                        assertThat(throwable.getMessage())
                                .doesNotContain(rawToken);
                    }
                });
    }

    @FunctionalInterface
    private interface ThrowingAction {

        void run();

    }

    private static class FakeGoogleSdkTokenVerifier
            implements GoogleSdkTokenVerifier {

        private final GoogleIdToken.Payload payload;
        private final Exception exception;
        private String verifiedToken;

        private FakeGoogleSdkTokenVerifier(
                GoogleIdToken.Payload payload,
                Exception exception
        ) {
            this.payload = payload;
            this.exception = exception;
        }

        static FakeGoogleSdkTokenVerifier returning(
                GoogleIdToken.Payload payload
        ) {
            return new FakeGoogleSdkTokenVerifier(payload, null);
        }

        static FakeGoogleSdkTokenVerifier throwing(IOException exception) {
            return new FakeGoogleSdkTokenVerifier(null, exception);
        }

        static FakeGoogleSdkTokenVerifier throwing(
                GeneralSecurityException exception
        ) {
            return new FakeGoogleSdkTokenVerifier(null, exception);
        }

        @Override
        public GoogleIdToken.Payload verify(String idToken)
                throws GeneralSecurityException, IOException {

            verifiedToken = idToken;

            if (exception instanceof IOException ioException) {
                throw ioException;
            }

            if (exception instanceof GeneralSecurityException securityException) {
                throw securityException;
            }

            return payload;
        }
    }
}
