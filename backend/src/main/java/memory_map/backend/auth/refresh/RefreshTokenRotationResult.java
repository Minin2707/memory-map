package memory_map.backend.auth.refresh;

import java.util.Objects;

public final class RefreshTokenRotationResult {

    private final String accessToken;
    private final RawRefreshToken refreshToken;

    public RefreshTokenRotationResult(
            String accessToken,
            RawRefreshToken refreshToken
    ) {
        this.accessToken = Objects.requireNonNull(
                accessToken,
                "accessToken must not be null"
        );

        if (accessToken.isBlank()) {
            throw new IllegalArgumentException(
                    "accessToken must not be blank"
            );
        }

        this.refreshToken = Objects.requireNonNull(
                refreshToken,
                "refreshToken must not be null"
        );
    }

    public String accessToken() {
        return accessToken;
    }

    public RawRefreshToken refreshToken() {
        return refreshToken;
    }

    @Override
    public boolean equals(Object other) {
        if (this == other) {
            return true;
        }

        if (!(other instanceof RefreshTokenRotationResult that)) {
            return false;
        }

        return accessToken.equals(that.accessToken)
                && refreshToken.equals(that.refreshToken);
    }

    @Override
    public int hashCode() {
        return Objects.hash(
                accessToken,
                refreshToken
        );
    }

    @Override
    public String toString() {
        return "RefreshTokenRotationResult[REDACTED]";
    }
}
