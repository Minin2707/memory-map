package memory_map.backend.auth.refresh;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class RefreshTokenRotationResultTest {

    private static final String ACCESS_TOKEN = "access-token";
    private static final RawRefreshToken REFRESH_TOKEN =
            new RawRefreshToken("refresh-token-value");

    @Test
    void shouldCreateRefreshTokenRotationResult() {

        RefreshTokenRotationResult result =
                new RefreshTokenRotationResult(
                        ACCESS_TOKEN,
                        REFRESH_TOKEN
                );

        assertThat(result.accessToken()).isEqualTo(ACCESS_TOKEN);
        assertThat(result.refreshToken()).isSameAs(REFRESH_TOKEN);
    }

    @Test
    void shouldRejectNullAccessToken() {

        assertThatThrownBy(
                () -> new RefreshTokenRotationResult(null, REFRESH_TOKEN)
        )
                .isInstanceOf(NullPointerException.class)
                .hasMessage("accessToken must not be null");
    }

    @Test
    void shouldRejectEmptyAccessToken() {

        assertThatThrownBy(
                () -> new RefreshTokenRotationResult("", REFRESH_TOKEN)
        )
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("accessToken must not be blank");
    }

    @Test
    void shouldRejectWhitespaceAccessToken() {

        assertThatThrownBy(
                () -> new RefreshTokenRotationResult("   ", REFRESH_TOKEN)
        )
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("accessToken must not be blank");
    }

    @Test
    void shouldRejectNullRefreshToken() {

        assertThatThrownBy(
                () -> new RefreshTokenRotationResult(ACCESS_TOKEN, null)
        )
                .isInstanceOf(NullPointerException.class)
                .hasMessage("refreshToken must not be null");
    }

    @Test
    void shouldCompareByValues() {

        RefreshTokenRotationResult first =
                new RefreshTokenRotationResult(
                        ACCESS_TOKEN,
                        new RawRefreshToken("same-refresh-token")
                );
        RefreshTokenRotationResult second =
                new RefreshTokenRotationResult(
                        ACCESS_TOKEN,
                        new RawRefreshToken("same-refresh-token")
                );
        RefreshTokenRotationResult other =
                new RefreshTokenRotationResult(
                        "other-access-token",
                        new RawRefreshToken("same-refresh-token")
                );

        assertThat(first).isEqualTo(second);
        assertThat(first).isNotEqualTo(other);
    }

    @Test
    void shouldProduceStableHashCode() {

        RefreshTokenRotationResult first =
                new RefreshTokenRotationResult(
                        ACCESS_TOKEN,
                        new RawRefreshToken("same-refresh-token")
                );
        RefreshTokenRotationResult second =
                new RefreshTokenRotationResult(
                        ACCESS_TOKEN,
                        new RawRefreshToken("same-refresh-token")
                );

        assertThat(first.hashCode()).isEqualTo(second.hashCode());
    }

    @Test
    void shouldRedactTokensInToString() {

        RefreshTokenRotationResult result =
                new RefreshTokenRotationResult(
                        ACCESS_TOKEN,
                        REFRESH_TOKEN
                );

        assertThat(result.toString())
                .isEqualTo("RefreshTokenRotationResult[REDACTED]")
                .doesNotContain(ACCESS_TOKEN)
                .doesNotContain(REFRESH_TOKEN.value());
    }
}
