package memory_map.backend.auth.jwt;

import memory_map.backend.auth.domain.AuthenticatedUser;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class DefaultAccessTokenServiceTest {

    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final Instant ISSUED_AT =
            Instant.parse("2026-01-01T10:00:00Z");

    @Test
    void shouldDelegateIssueToAccessTokenIssuer() {

        FakeAccessTokenIssuer issuer = new FakeAccessTokenIssuer();
        FakeAccessTokenVerifier verifier = new FakeAccessTokenVerifier();
        DefaultAccessTokenService service =
                new DefaultAccessTokenService(issuer, verifier);

        String token = service.issueAccessToken(USER_ID, ISSUED_AT);

        assertThat(token).isEqualTo("issued-access-token");
        assertThat(issuer.userId).isEqualTo(USER_ID);
        assertThat(issuer.issuedAt).isEqualTo(ISSUED_AT);
    }

    @Test
    void shouldDelegateVerificationToAccessTokenVerifier() {

        FakeAccessTokenIssuer issuer = new FakeAccessTokenIssuer();
        FakeAccessTokenVerifier verifier = new FakeAccessTokenVerifier();
        DefaultAccessTokenService service =
                new DefaultAccessTokenService(issuer, verifier);

        AuthenticatedUser authenticatedUser =
                service.verifyAccessToken("access-token");

        assertThat(authenticatedUser.userId()).isEqualTo(USER_ID);
        assertThat(verifier.accessToken).isEqualTo("access-token");
    }

    @Test
    void shouldRejectNullIssuerDependency() {

        FakeAccessTokenVerifier verifier = new FakeAccessTokenVerifier();

        assertThatThrownBy(() -> new DefaultAccessTokenService(null, verifier))
                .isInstanceOf(NullPointerException.class);
    }

    @Test
    void shouldRejectNullVerifierDependency() {

        FakeAccessTokenIssuer issuer = new FakeAccessTokenIssuer();

        assertThatThrownBy(() -> new DefaultAccessTokenService(issuer, null))
                .isInstanceOf(NullPointerException.class);
    }

    private static class FakeAccessTokenIssuer implements AccessTokenIssuer {

        private UUID userId;
        private Instant issuedAt;

        @Override
        public String issue(
                UUID userId,
                Instant issuedAt
        ) {
            this.userId = userId;
            this.issuedAt = issuedAt;

            return "issued-access-token";
        }
    }

    private static class FakeAccessTokenVerifier implements AccessTokenVerifier {

        private String accessToken;

        @Override
        public AuthenticatedUser verify(String accessToken) {
            this.accessToken = accessToken;

            return new AuthenticatedUser(USER_ID);
        }
    }
}
