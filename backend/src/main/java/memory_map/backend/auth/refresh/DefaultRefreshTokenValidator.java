package memory_map.backend.auth.refresh;

import memory_map.backend.auth.domain.RefreshToken;

import java.time.Instant;
import java.util.Objects;

public class DefaultRefreshTokenValidator implements RefreshTokenValidator {

    private static final String INVALID_TOKEN_MESSAGE =
            "Refresh token is invalid";

    @Override
    public void validate(
            RefreshToken refreshToken,
            Instant currentTime
    ) {
        Objects.requireNonNull(
                refreshToken,
                "refreshToken must not be null"
        );
        Objects.requireNonNull(
                currentTime,
                "currentTime must not be null"
        );

        if (refreshToken.revokedAt() != null) {
            throw invalidToken();
        }

        if (refreshToken.consumedAt() != null) {
            throw invalidToken();
        }

        if (!refreshToken.expiresAt().isAfter(currentTime)) {
            throw invalidToken();
        }
    }

    private static InvalidRefreshTokenException invalidToken() {
        return new InvalidRefreshTokenException(
                INVALID_TOKEN_MESSAGE
        );
    }
}
