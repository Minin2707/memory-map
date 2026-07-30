package memory_map.backend.auth.refresh;

import memory_map.backend.auth.domain.RefreshToken;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.Locale;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class DefaultRefreshTokenValidatorTest {

    private static final String INVALID_TOKEN_MESSAGE =
            "Refresh token is invalid";
    private static final UUID TOKEN_ID =
            UUID.fromString(
                    "00000000-0000-0000-0000-000000000001"
            );
    private static final UUID USER_ID =
            UUID.fromString(
                    "00000000-0000-0000-0000-000000000002"
            );
    private static final Instant CREATED_AT =
            Instant.parse("2026-01-01T10:00:00Z");
    private static final Instant CURRENT_TIME =
            Instant.parse("2026-01-10T10:00:00Z");
    private static final String TOKEN_HASH =
            "0123456789abcdef0123456789abcdef"
                    + "0123456789abcdef0123456789abcdef";

    @Test
    void shouldAcceptActiveRefreshToken() {

        RefreshToken token = refreshToken(
                CURRENT_TIME.plusSeconds(1),
                null
        );

        assertThatCode(
                () -> validator().validate(token, CURRENT_TIME)
        ).doesNotThrowAnyException();
    }

    @Test
    void shouldAcceptTokenExpiringAfterCurrentTime() {

        RefreshToken token = refreshToken(
                CURRENT_TIME.plusSeconds(60),
                null
        );

        assertThatCode(
                () -> validator().validate(token, CURRENT_TIME)
        ).doesNotThrowAnyException();
    }

    @Test
    void shouldRejectRevokedRefreshToken() {

        RefreshToken token = refreshToken(
                CURRENT_TIME.plusSeconds(1),
                CURRENT_TIME.minusSeconds(1)
        );

        assertInvalidToken(token);
    }

    @Test
    void shouldRejectExpiredRefreshToken() {

        RefreshToken token = refreshToken(
                CURRENT_TIME.minusSeconds(1),
                null
        );

        assertInvalidToken(token);
    }

    @Test
    void shouldRejectRefreshTokenExpiringExactlyAtCurrentTime() {

        RefreshToken token = refreshToken(
                CURRENT_TIME,
                null
        );

        assertInvalidToken(token);
    }

    @Test
    void shouldUseSameSafeMessageForRevokedAndExpiredTokens() {

        RefreshToken revokedToken = refreshToken(
                CURRENT_TIME.plusSeconds(1),
                CURRENT_TIME.minusSeconds(1)
        );
        RefreshToken expiredToken = refreshToken(
                CURRENT_TIME.minusSeconds(1),
                null
        );

        InvalidRefreshTokenException revokedException =
                catchInvalidToken(revokedToken);
        InvalidRefreshTokenException expiredException =
                catchInvalidToken(expiredToken);

        assertThat(revokedException).hasMessage(INVALID_TOKEN_MESSAGE);
        assertThat(expiredException).hasMessage(INVALID_TOKEN_MESSAGE);
        assertThat(revokedException.getMessage())
                .isEqualTo(expiredException.getMessage());
        assertSafeMessage(revokedException);
        assertSafeMessage(expiredException);
    }

    @Test
    void shouldRejectNullRefreshToken() {

        assertThatThrownBy(
                () -> validator().validate(null, CURRENT_TIME)
        )
                .isInstanceOf(NullPointerException.class)
                .hasMessage("refreshToken must not be null");
    }

    @Test
    void shouldRejectNullCurrentTime() {

        assertThatThrownBy(
                () -> validator().validate(
                        refreshToken(
                                CURRENT_TIME.plusSeconds(1),
                                null
                        ),
                        null
                )
        )
                .isInstanceOf(NullPointerException.class)
                .hasMessage("currentTime must not be null");
    }

    private static DefaultRefreshTokenValidator validator() {
        return new DefaultRefreshTokenValidator();
    }

    private static RefreshToken refreshToken(
            Instant expiresAt,
            Instant revokedAt
    ) {
        return new RefreshToken(
                TOKEN_ID,
                USER_ID,
                TOKEN_HASH,
                CREATED_AT,
                expiresAt,
                revokedAt
        );
    }

    private static void assertInvalidToken(RefreshToken refreshToken) {
        assertThatThrownBy(
                () -> validator().validate(refreshToken, CURRENT_TIME)
        )
                .isInstanceOf(InvalidRefreshTokenException.class)
                .hasMessage(INVALID_TOKEN_MESSAGE)
                .satisfies(throwable -> assertSafeMessage(
                        (InvalidRefreshTokenException) throwable
                ));
    }

    private static InvalidRefreshTokenException catchInvalidToken(
            RefreshToken refreshToken
    ) {
        try {
            validator().validate(refreshToken, CURRENT_TIME);
        } catch (InvalidRefreshTokenException exception) {
            return exception;
        }

        throw new AssertionError("Expected InvalidRefreshTokenException");
    }

    private static void assertSafeMessage(
            InvalidRefreshTokenException exception
    ) {
        String message = exception.getMessage();

        assertThat(message)
                .doesNotContain(TOKEN_HASH)
                .doesNotContain(TOKEN_ID.toString())
                .doesNotContain(USER_ID.toString())
                .doesNotContain(CREATED_AT.toString())
                .doesNotContain(CURRENT_TIME.toString());
        assertThat(message.toLowerCase(Locale.ROOT))
                .doesNotContain("revoked")
                .doesNotContain("expired");
    }
}
