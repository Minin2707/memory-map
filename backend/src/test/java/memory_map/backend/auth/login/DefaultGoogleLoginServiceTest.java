package memory_map.backend.auth.login;

import memory_map.backend.auth.domain.GoogleIdentity;
import memory_map.backend.auth.google.GoogleIdentityVerificationException;
import memory_map.backend.auth.google.GoogleIdentityVerifier;
import memory_map.backend.auth.refresh.RawRefreshToken;
import memory_map.backend.user.domain.User;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class DefaultGoogleLoginServiceTest {

    private static final String GOOGLE_ID_TOKEN =
            "raw-google-id-token";
    private static final UUID NEW_USER_ID =
            UUID.fromString(
                    "00000000-0000-0000-0000-000000000001"
            );
    private static final UUID NEW_REFRESH_TOKEN_ID =
            UUID.fromString(
                    "00000000-0000-0000-0000-000000000002"
            );
    private static final Instant CURRENT_TIME =
            Instant.parse("2026-01-01T10:00:00Z");
    private static final GoogleIdentity IDENTITY =
            new GoogleIdentity(
                    "google-subject-123",
                    "Konstantin",
                    "https://example.com/avatar.png"
            );
    private static final GoogleLoginResult RESULT =
            new GoogleLoginResult(
                    new User(
                            NEW_USER_ID,
                            "google-subject-123",
                            "Konstantin",
                            "https://example.com/avatar.png",
                            CURRENT_TIME,
                            CURRENT_TIME
                    ),
                    "issued-access-token",
                    new RawRefreshToken("raw-refresh-token")
            );

    @Test
    void shouldVerifyGoogleIdToken() {

        TestContext context = testContext();

        context.service().login(
                GOOGLE_ID_TOKEN,
                NEW_USER_ID,
                NEW_REFRESH_TOKEN_ID,
                CURRENT_TIME
        );

        assertThat(context.verifier().receivedGoogleIdToken())
                .isEqualTo(GOOGLE_ID_TOKEN);
    }

    @Test
    void shouldDelegateVerifiedIdentityToTransaction() {

        TestContext context = testContext();

        context.service().login(
                GOOGLE_ID_TOKEN,
                NEW_USER_ID,
                NEW_REFRESH_TOKEN_ID,
                CURRENT_TIME
        );

        assertThat(context.transaction().receivedIdentity())
                .isEqualTo(IDENTITY);
        assertThat(context.events()).containsExactly(
                "verify",
                "transaction"
        );
    }

    @Test
    void shouldPassProvidedIdentifiersAndCurrentTime() {

        TestContext context = testContext();

        context.service().login(
                GOOGLE_ID_TOKEN,
                NEW_USER_ID,
                NEW_REFRESH_TOKEN_ID,
                CURRENT_TIME
        );

        assertThat(context.transaction().receivedNewUserId())
                .isEqualTo(NEW_USER_ID);
        assertThat(context.transaction().receivedNewRefreshTokenId())
                .isEqualTo(NEW_REFRESH_TOKEN_ID);
        assertThat(context.transaction().receivedCurrentTime())
                .isEqualTo(CURRENT_TIME);
    }

    @Test
    void shouldReturnTransactionResult() {

        TestContext context = testContext();

        GoogleLoginResult result = context.service().login(
                GOOGLE_ID_TOKEN,
                NEW_USER_ID,
                NEW_REFRESH_TOKEN_ID,
                CURRENT_TIME
        );

        assertThat(result).isEqualTo(RESULT);
    }

    @Test
    void shouldRejectNullGoogleIdToken() {

        assertThatThrownBy(() -> testContext().service().login(
                null,
                NEW_USER_ID,
                NEW_REFRESH_TOKEN_ID,
                CURRENT_TIME
        ))
                .isInstanceOf(GoogleIdentityVerificationException.class)
                .hasMessage("Google ID token verification failed");
    }

    @Test
    void shouldRejectEmptyGoogleIdToken() {

        assertThatThrownBy(() -> testContext().service().login(
                "",
                NEW_USER_ID,
                NEW_REFRESH_TOKEN_ID,
                CURRENT_TIME
        ))
                .isInstanceOf(GoogleIdentityVerificationException.class)
                .hasMessage("Google ID token verification failed");
    }

    @Test
    void shouldRejectWhitespaceGoogleIdToken() {

        assertThatThrownBy(() -> testContext().service().login(
                "   ",
                NEW_USER_ID,
                NEW_REFRESH_TOKEN_ID,
                CURRENT_TIME
        ))
                .isInstanceOf(GoogleIdentityVerificationException.class)
                .hasMessage("Google ID token verification failed");
    }

    @Test
    void shouldRejectNullNewUserId() {

        assertThatThrownBy(() -> testContext().service().login(
                GOOGLE_ID_TOKEN,
                null,
                NEW_REFRESH_TOKEN_ID,
                CURRENT_TIME
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("newUserId must not be null");
    }

    @Test
    void shouldRejectNullNewRefreshTokenId() {

        assertThatThrownBy(() -> testContext().service().login(
                GOOGLE_ID_TOKEN,
                NEW_USER_ID,
                null,
                CURRENT_TIME
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("newRefreshTokenId must not be null");
    }

    @Test
    void shouldRejectNullCurrentTime() {

        assertThatThrownBy(() -> testContext().service().login(
                GOOGLE_ID_TOKEN,
                NEW_USER_ID,
                NEW_REFRESH_TOKEN_ID,
                null
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("currentTime must not be null");
    }

    @Test
    void shouldRejectNullVerifierDependency() {

        assertThatThrownBy(() -> new DefaultGoogleLoginService(
                null,
                testContext().transaction()
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("googleIdentityVerifier must not be null");
    }

    @Test
    void shouldRejectNullTransactionDependency() {

        assertThatThrownBy(() -> new DefaultGoogleLoginService(
                testContext().verifier(),
                null
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("googleLoginTransaction must not be null");
    }

    @Test
    void shouldNotCallTransactionWhenVerificationFails() {

        TestContext context = testContext();
        context.verifier().verificationFailure();

        assertThatThrownBy(() -> context.service().login(
                GOOGLE_ID_TOKEN,
                NEW_USER_ID,
                NEW_REFRESH_TOKEN_ID,
                CURRENT_TIME
        ))
                .isInstanceOf(GoogleIdentityVerificationException.class)
                .hasMessage("Google ID token verification failed");

        assertThat(context.events()).containsExactly("verify");
        assertThat(context.transaction().calls()).isZero();
    }

    private static TestContext testContext() {
        List<String> events = new ArrayList<>();
        FakeGoogleIdentityVerifier verifier =
                new FakeGoogleIdentityVerifier(events);
        FakeGoogleLoginTransaction transaction =
                new FakeGoogleLoginTransaction(events);

        return new TestContext(
                events,
                verifier,
                transaction,
                new DefaultGoogleLoginService(
                        verifier,
                        transaction
                )
        );
    }

    private record TestContext(
            List<String> events,
            FakeGoogleIdentityVerifier verifier,
            FakeGoogleLoginTransaction transaction,
            DefaultGoogleLoginService service
    ) {
    }

    private static final class FakeGoogleIdentityVerifier
            implements GoogleIdentityVerifier {

        private final List<String> events;
        private boolean verificationFailure;
        private String receivedGoogleIdToken;

        private FakeGoogleIdentityVerifier(List<String> events) {
            this.events = events;
        }

        @Override
        public GoogleIdentity verify(String idToken) {
            events.add("verify");
            receivedGoogleIdToken = idToken;

            if (verificationFailure) {
                throw new GoogleIdentityVerificationException(
                        "Google ID token verification failed"
                );
            }

            return IDENTITY;
        }

        private void verificationFailure() {
            verificationFailure = true;
        }

        private String receivedGoogleIdToken() {
            return receivedGoogleIdToken;
        }
    }

    private static final class FakeGoogleLoginTransaction
            implements GoogleLoginTransaction {

        private final List<String> events;
        private GoogleIdentity receivedIdentity;
        private UUID receivedNewUserId;
        private UUID receivedNewRefreshTokenId;
        private Instant receivedCurrentTime;
        private int calls;

        private FakeGoogleLoginTransaction(List<String> events) {
            this.events = events;
        }

        @Override
        public GoogleLoginResult login(
                GoogleIdentity identity,
                UUID newUserId,
                UUID newRefreshTokenId,
                Instant currentTime
        ) {
            events.add("transaction");
            calls++;
            receivedIdentity = identity;
            receivedNewUserId = newUserId;
            receivedNewRefreshTokenId = newRefreshTokenId;
            receivedCurrentTime = currentTime;

            return RESULT;
        }

        private GoogleIdentity receivedIdentity() {
            return receivedIdentity;
        }

        private UUID receivedNewUserId() {
            return receivedNewUserId;
        }

        private UUID receivedNewRefreshTokenId() {
            return receivedNewRefreshTokenId;
        }

        private Instant receivedCurrentTime() {
            return receivedCurrentTime;
        }

        private int calls() {
            return calls;
        }
    }
}
