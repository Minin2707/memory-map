package memory_map.backend.auth.login;

import memory_map.backend.auth.refresh.RawRefreshToken;
import memory_map.backend.user.domain.User;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class GoogleLoginResultTest {

    private static final UUID USER_ID =
            UUID.fromString(
                    "00000000-0000-0000-0000-000000000001"
            );
    private static final Instant CREATED_AT =
            Instant.parse("2026-01-01T10:00:00Z");
    private static final String ACCESS_TOKEN =
            "issued-access-token";
    private static final RawRefreshToken REFRESH_TOKEN =
            new RawRefreshToken("raw-refresh-token");

    @Test
    void shouldCreateGoogleLoginResult() {

        User user = user();

        GoogleLoginResult result = new GoogleLoginResult(
                user,
                ACCESS_TOKEN,
                REFRESH_TOKEN
        );

        assertThat(result.user()).isEqualTo(user);
        assertThat(result.accessToken()).isEqualTo(ACCESS_TOKEN);
        assertThat(result.refreshToken()).isEqualTo(REFRESH_TOKEN);
    }

    @Test
    void shouldRejectNullUser() {

        assertThatThrownBy(() -> new GoogleLoginResult(
                null,
                ACCESS_TOKEN,
                REFRESH_TOKEN
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("user must not be null");
    }

    @Test
    void shouldRejectNullAccessToken() {

        assertThatThrownBy(() -> new GoogleLoginResult(
                user(),
                null,
                REFRESH_TOKEN
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("accessToken must not be null");
    }

    @Test
    void shouldRejectEmptyAccessToken() {

        assertThatThrownBy(() -> new GoogleLoginResult(
                user(),
                "",
                REFRESH_TOKEN
        ))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("accessToken must not be blank");
    }

    @Test
    void shouldRejectWhitespaceAccessToken() {

        assertThatThrownBy(() -> new GoogleLoginResult(
                user(),
                "   ",
                REFRESH_TOKEN
        ))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("accessToken must not be blank");
    }

    @Test
    void shouldRejectNullRefreshToken() {

        assertThatThrownBy(() -> new GoogleLoginResult(
                user(),
                ACCESS_TOKEN,
                null
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("refreshToken must not be null");
    }

    @Test
    void shouldCompareByValues() {

        GoogleLoginResult first = new GoogleLoginResult(
                user(),
                ACCESS_TOKEN,
                REFRESH_TOKEN
        );
        GoogleLoginResult second = new GoogleLoginResult(
                user(),
                ACCESS_TOKEN,
                new RawRefreshToken("raw-refresh-token")
        );

        assertThat(first).isEqualTo(second);
    }

    @Test
    void shouldProduceStableHashCode() {

        GoogleLoginResult first = new GoogleLoginResult(
                user(),
                ACCESS_TOKEN,
                REFRESH_TOKEN
        );
        GoogleLoginResult second = new GoogleLoginResult(
                user(),
                ACCESS_TOKEN,
                new RawRefreshToken("raw-refresh-token")
        );

        assertThat(first).hasSameHashCodeAs(second);
    }

    @Test
    void shouldRedactSensitiveValuesInToString() {

        GoogleLoginResult result = new GoogleLoginResult(
                user(),
                ACCESS_TOKEN,
                REFRESH_TOKEN
        );

        assertThat(result.toString())
                .isEqualTo("GoogleLoginResult[REDACTED]")
                .doesNotContain(ACCESS_TOKEN)
                .doesNotContain(REFRESH_TOKEN.value())
                .doesNotContain("google-subject-123")
                .doesNotContain("Konstantin");
    }

    private static User user() {
        return new User(
                USER_ID,
                "google-subject-123",
                "Konstantin",
                "https://example.com/avatar.png",
                CREATED_AT,
                CREATED_AT
        );
    }
}
