package memory_map.backend.auth.api;

import org.junit.jupiter.api.Test;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class AuthSensitiveDtoTest {

    private static final UUID USER_ID =
            UUID.fromString(
                    "00000000-0000-0000-0000-000000000001"
            );
    private static final AuthUserResponse USER =
            new AuthUserResponse(
                    USER_ID,
                    "Memory Map User",
                    "https://example.com/avatar.png",
                    false
            );

    @Test
    void shouldRedactGoogleIdTokenInGoogleLoginRequestToString() {

        String rawGoogleToken = "raw-google-id-token";

        GoogleLoginRequest request =
                new GoogleLoginRequest(rawGoogleToken);

        assertThat(request.toString())
                .isEqualTo("GoogleLoginRequest[REDACTED]")
                .doesNotContain(rawGoogleToken);
    }

    @Test
    void shouldRedactRefreshTokenInRefreshTokenRequestToString() {

        String rawRefreshToken = "raw-refresh-token";

        RefreshTokenRequest request =
                new RefreshTokenRequest(rawRefreshToken);

        assertThat(request.toString())
                .isEqualTo("RefreshTokenRequest[REDACTED]")
                .doesNotContain(rawRefreshToken);
    }

    @Test
    void shouldRedactTokensInAuthTokenResponseToString() {

        String accessToken = "signed-access-token";
        String refreshToken = "raw-refresh-token";

        AuthTokenResponse response = new AuthTokenResponse(
                accessToken,
                refreshToken
        );

        assertThat(response.toString())
                .isEqualTo("AuthTokenResponse[REDACTED]")
                .doesNotContain(accessToken)
                .doesNotContain(refreshToken);
    }

    @Test
    void shouldRedactTokensAndUserInGoogleLoginResponseToString() {

        String accessToken = "signed-access-token";
        String refreshToken = "raw-refresh-token";

        GoogleLoginResponse response = new GoogleLoginResponse(
                USER,
                accessToken,
                refreshToken
        );

        assertThat(response.toString())
                .isEqualTo("GoogleLoginResponse[REDACTED]")
                .doesNotContain(accessToken)
                .doesNotContain(refreshToken)
                .doesNotContain(USER.id().toString())
                .doesNotContain(USER.displayName())
                .doesNotContain(USER.avatarUrl());
    }

    @Test
    void shouldPreserveGoogleLoginRequestValueSemantics() {

        GoogleLoginRequest first =
                new GoogleLoginRequest("raw-google-id-token");
        GoogleLoginRequest second =
                new GoogleLoginRequest("raw-google-id-token");

        assertThat(first).isEqualTo(second);
        assertThat(first).hasSameHashCodeAs(second);
        assertThat(first.idToken()).isEqualTo("raw-google-id-token");
    }

    @Test
    void shouldPreserveRefreshTokenRequestValueSemantics() {

        RefreshTokenRequest first =
                new RefreshTokenRequest("raw-refresh-token");
        RefreshTokenRequest second =
                new RefreshTokenRequest("raw-refresh-token");

        assertThat(first).isEqualTo(second);
        assertThat(first).hasSameHashCodeAs(second);
        assertThat(first.refreshToken()).isEqualTo("raw-refresh-token");
    }

    @Test
    void shouldPreserveAuthTokenResponseValueSemantics() {

        AuthTokenResponse first = new AuthTokenResponse(
                "signed-access-token",
                "raw-refresh-token"
        );
        AuthTokenResponse second = new AuthTokenResponse(
                "signed-access-token",
                "raw-refresh-token"
        );

        assertThat(first).isEqualTo(second);
        assertThat(first).hasSameHashCodeAs(second);
        assertThat(first.accessToken()).isEqualTo("signed-access-token");
        assertThat(first.refreshToken()).isEqualTo("raw-refresh-token");
    }

    @Test
    void shouldPreserveGoogleLoginResponseValueSemantics() {

        GoogleLoginResponse first = new GoogleLoginResponse(
                USER,
                "signed-access-token",
                "raw-refresh-token"
        );
        GoogleLoginResponse second = new GoogleLoginResponse(
                USER,
                "signed-access-token",
                "raw-refresh-token"
        );

        assertThat(first).isEqualTo(second);
        assertThat(first).hasSameHashCodeAs(second);
        assertThat(first.user()).isEqualTo(USER);
        assertThat(first.accessToken()).isEqualTo("signed-access-token");
        assertThat(first.refreshToken()).isEqualTo("raw-refresh-token");
    }

    @Test
    void shouldRejectNullAccessTokenInAuthTokenResponse() {

        assertThatThrownBy(() -> new AuthTokenResponse(
                null,
                "raw-refresh-token"
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("accessToken must not be null");
    }

    @Test
    void shouldRejectBlankAccessTokenInAuthTokenResponse() {

        assertThatThrownBy(() -> new AuthTokenResponse(
                "   ",
                "raw-refresh-token"
        ))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("accessToken must not be blank");
    }

    @Test
    void shouldRejectNullRefreshTokenInAuthTokenResponse() {

        assertThatThrownBy(() -> new AuthTokenResponse(
                "signed-access-token",
                null
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("refreshToken must not be null");
    }

    @Test
    void shouldRejectBlankRefreshTokenInAuthTokenResponse() {

        assertThatThrownBy(() -> new AuthTokenResponse(
                "signed-access-token",
                "   "
        ))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("refreshToken must not be blank");
    }

    @Test
    void shouldRejectNullUserInGoogleLoginResponse() {

        assertThatThrownBy(() -> new GoogleLoginResponse(
                null,
                "signed-access-token",
                "raw-refresh-token"
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("user must not be null");
    }

    @Test
    void shouldRejectNullAccessTokenInGoogleLoginResponse() {

        assertThatThrownBy(() -> new GoogleLoginResponse(
                USER,
                null,
                "raw-refresh-token"
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("accessToken must not be null");
    }

    @Test
    void shouldRejectBlankAccessTokenInGoogleLoginResponse() {

        assertThatThrownBy(() -> new GoogleLoginResponse(
                USER,
                "   ",
                "raw-refresh-token"
        ))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("accessToken must not be blank");
    }

    @Test
    void shouldRejectNullRefreshTokenInGoogleLoginResponse() {

        assertThatThrownBy(() -> new GoogleLoginResponse(
                USER,
                "signed-access-token",
                null
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("refreshToken must not be null");
    }

    @Test
    void shouldRejectBlankRefreshTokenInGoogleLoginResponse() {

        assertThatThrownBy(() -> new GoogleLoginResponse(
                USER,
                "signed-access-token",
                "   "
        ))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("refreshToken must not be blank");
    }
}
