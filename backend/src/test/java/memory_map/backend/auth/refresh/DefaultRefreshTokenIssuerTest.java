package memory_map.backend.auth.refresh;

import memory_map.backend.auth.domain.RefreshToken;
import org.junit.jupiter.api.Test;

import java.time.Duration;
import java.time.Instant;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class DefaultRefreshTokenIssuerTest {

    private static final UUID TOKEN_ID =
            UUID.fromString(
                    "00000000-0000-0000-0000-000000000001"
            );
    private static final UUID USER_ID =
            UUID.fromString(
                    "00000000-0000-0000-0000-000000000002"
            );
    private static final Instant ISSUED_AT =
            Instant.parse("2026-01-01T10:00:00Z");
    private static final Duration TTL =
            Duration.ofDays(30);
    private static final RawRefreshToken RAW_TOKEN =
            new RawRefreshToken("deterministic-refresh-token");
    private static final String TOKEN_HASH =
            "0123456789abcdef0123456789abcdef"
                    + "0123456789abcdef0123456789abcdef";

    @Test
    void shouldIssueRawAndPersistedRefreshToken() {

        IssuedRefreshToken issued = issuer().issue(
                TOKEN_ID,
                USER_ID,
                ISSUED_AT
        );

        assertThat(issued.rawToken()).isSameAs(RAW_TOKEN);
        assertThat(issued.refreshToken()).isEqualTo(expectedRefreshToken());
    }

    @Test
    void shouldUseProvidedTokenId() {

        IssuedRefreshToken issued = issuer().issue(
                TOKEN_ID,
                USER_ID,
                ISSUED_AT
        );

        assertThat(issued.refreshToken().id()).isEqualTo(TOKEN_ID);
    }

    @Test
    void shouldUseProvidedUserId() {

        IssuedRefreshToken issued = issuer().issue(
                TOKEN_ID,
                USER_ID,
                ISSUED_AT
        );

        assertThat(issued.refreshToken().userId()).isEqualTo(USER_ID);
    }

    @Test
    void shouldUseProvidedIssuedAt() {

        IssuedRefreshToken issued = issuer().issue(
                TOKEN_ID,
                USER_ID,
                ISSUED_AT
        );

        assertThat(issued.refreshToken().createdAt()).isEqualTo(ISSUED_AT);
    }

    @Test
    void shouldSetExpirationFromConfiguredTtl() {

        IssuedRefreshToken issued = issuer().issue(
                TOKEN_ID,
                USER_ID,
                ISSUED_AT
        );

        assertThat(issued.refreshToken().expiresAt())
                .isEqualTo(ISSUED_AT.plus(TTL));
    }

    @Test
    void shouldStoreOnlyHashInPersistedRefreshToken() {

        IssuedRefreshToken issued = issuer().issue(
                TOKEN_ID,
                USER_ID,
                ISSUED_AT
        );

        assertThat(issued.refreshToken().tokenHash())
                .isEqualTo(TOKEN_HASH)
                .isNotEqualTo(issued.rawToken().value());
    }

    @Test
    void shouldCreateActiveRefreshToken() {

        IssuedRefreshToken issued = issuer().issue(
                TOKEN_ID,
                USER_ID,
                ISSUED_AT
        );

        assertThat(issued.refreshToken().revokedAt()).isNull();
    }

    @Test
    void shouldPassGeneratedRawTokenToHasher() {

        FakeRawRefreshTokenGenerator generator =
                new FakeRawRefreshTokenGenerator(RAW_TOKEN);
        FakeRefreshTokenHasher hasher =
                new FakeRefreshTokenHasher(TOKEN_HASH);
        DefaultRefreshTokenIssuer issuer = new DefaultRefreshTokenIssuer(
                generator,
                hasher,
                new RefreshTokenProperties(TTL)
        );

        issuer.issue(
                TOKEN_ID,
                USER_ID,
                ISSUED_AT
        );

        assertThat(generator.calls()).isEqualTo(1);
        assertThat(hasher.receivedToken()).isSameAs(RAW_TOKEN);
    }

    @Test
    void shouldRejectNullTokenId() {

        assertThatThrownBy(
                () -> issuer().issue(null, USER_ID, ISSUED_AT)
        )
                .isInstanceOf(NullPointerException.class)
                .hasMessage("tokenId must not be null");
    }

    @Test
    void shouldRejectNullUserId() {

        assertThatThrownBy(
                () -> issuer().issue(TOKEN_ID, null, ISSUED_AT)
        )
                .isInstanceOf(NullPointerException.class)
                .hasMessage("userId must not be null");
    }

    @Test
    void shouldRejectNullIssuedAt() {

        assertThatThrownBy(
                () -> issuer().issue(TOKEN_ID, USER_ID, null)
        )
                .isInstanceOf(NullPointerException.class)
                .hasMessage("issuedAt must not be null");
    }

    @Test
    void shouldRejectNullGeneratorDependency() {

        assertThatThrownBy(() -> new DefaultRefreshTokenIssuer(
                null,
                new FakeRefreshTokenHasher(TOKEN_HASH),
                new RefreshTokenProperties(TTL)
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("rawTokenGenerator must not be null");
    }

    @Test
    void shouldRejectNullHasherDependency() {

        assertThatThrownBy(() -> new DefaultRefreshTokenIssuer(
                new FakeRawRefreshTokenGenerator(RAW_TOKEN),
                null,
                new RefreshTokenProperties(TTL)
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("tokenHasher must not be null");
    }

    @Test
    void shouldRejectNullPropertiesDependency() {

        assertThatThrownBy(() -> new DefaultRefreshTokenIssuer(
                new FakeRawRefreshTokenGenerator(RAW_TOKEN),
                new FakeRefreshTokenHasher(TOKEN_HASH),
                null
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("properties must not be null");
    }

    private static DefaultRefreshTokenIssuer issuer() {
        return new DefaultRefreshTokenIssuer(
                new FakeRawRefreshTokenGenerator(RAW_TOKEN),
                new FakeRefreshTokenHasher(TOKEN_HASH),
                new RefreshTokenProperties(TTL)
        );
    }

    private static RefreshToken expectedRefreshToken() {
        return new RefreshToken(
                TOKEN_ID,
                USER_ID,
                TOKEN_HASH,
                ISSUED_AT,
                ISSUED_AT.plus(TTL),
                null
        );
    }

    private static final class FakeRawRefreshTokenGenerator
            implements RawRefreshTokenGenerator {

        private final RawRefreshToken token;
        private int calls;

        private FakeRawRefreshTokenGenerator(RawRefreshToken token) {
            this.token = token;
        }

        @Override
        public RawRefreshToken generate() {
            calls++;
            return token;
        }

        private int calls() {
            return calls;
        }
    }

    private static final class FakeRefreshTokenHasher
            implements RefreshTokenHasher {

        private final String hash;
        private RawRefreshToken receivedToken;

        private FakeRefreshTokenHasher(String hash) {
            this.hash = hash;
        }

        @Override
        public String hash(RawRefreshToken rawToken) {
            receivedToken = rawToken;
            return hash;
        }

        private RawRefreshToken receivedToken() {
            return receivedToken;
        }
    }
}
