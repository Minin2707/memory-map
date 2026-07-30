package memory_map.backend.auth.refresh;

import memory_map.backend.auth.domain.RefreshToken;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class IssuedRefreshTokenTest {

    private static final UUID TOKEN_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000002");
    private static final Instant CREATED_AT =
            Instant.parse("2026-01-01T10:00:00Z");
    private static final Instant EXPIRES_AT =
            Instant.parse("2026-01-31T10:00:00Z");
    private static final String TOKEN_HASH =
            "0123456789abcdef0123456789abcdef"
                    + "0123456789abcdef0123456789abcdef";

    @Test
    void shouldCreateIssuedRefreshToken() {

        RawRefreshToken rawToken = rawToken();
        RefreshToken refreshToken = refreshToken();

        IssuedRefreshToken issuedRefreshToken =
                new IssuedRefreshToken(rawToken, refreshToken);

        assertThat(issuedRefreshToken.rawToken()).isSameAs(rawToken);
        assertThat(issuedRefreshToken.refreshToken()).isSameAs(refreshToken);
    }

    @Test
    void shouldRejectNullRawToken() {

        assertThatThrownBy(
                () -> new IssuedRefreshToken(null, refreshToken())
        )
                .isInstanceOf(NullPointerException.class)
                .hasMessage("rawToken must not be null");
    }

    @Test
    void shouldRejectNullRefreshToken() {

        assertThatThrownBy(
                () -> new IssuedRefreshToken(rawToken(), null)
        )
                .isInstanceOf(NullPointerException.class)
                .hasMessage("refreshToken must not be null");
    }

    @Test
    void shouldCompareByValues() {

        IssuedRefreshToken first = new IssuedRefreshToken(
                new RawRefreshToken("same-raw-token"),
                refreshToken()
        );
        IssuedRefreshToken second = new IssuedRefreshToken(
                new RawRefreshToken("same-raw-token"),
                refreshToken()
        );
        IssuedRefreshToken other = new IssuedRefreshToken(
                new RawRefreshToken("other-raw-token"),
                refreshToken()
        );

        assertThat(first).isEqualTo(second);
        assertThat(first).isNotEqualTo(other);
    }

    @Test
    void shouldProduceStableHashCode() {

        IssuedRefreshToken first = new IssuedRefreshToken(
                new RawRefreshToken("same-raw-token"),
                refreshToken()
        );
        IssuedRefreshToken second = new IssuedRefreshToken(
                new RawRefreshToken("same-raw-token"),
                refreshToken()
        );

        assertThat(first.hashCode()).isEqualTo(second.hashCode());
    }

    @Test
    void shouldRedactSensitiveValuesInToString() {

        RawRefreshToken rawToken = rawToken();
        RefreshToken refreshToken = refreshToken();
        IssuedRefreshToken issuedRefreshToken =
                new IssuedRefreshToken(rawToken, refreshToken);

        assertThat(issuedRefreshToken.toString())
                .isEqualTo("IssuedRefreshToken[REDACTED]")
                .doesNotContain(rawToken.value())
                .doesNotContain(refreshToken.tokenHash());
    }

    private static RawRefreshToken rawToken() {
        return new RawRefreshToken("deterministic-refresh-token");
    }

    private static RefreshToken refreshToken() {
        return new RefreshToken(
                TOKEN_ID,
                USER_ID,
                TOKEN_HASH,
                CREATED_AT,
                EXPIRES_AT,
                null
        );
    }
}
