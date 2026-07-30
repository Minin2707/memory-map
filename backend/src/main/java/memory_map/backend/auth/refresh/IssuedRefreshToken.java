package memory_map.backend.auth.refresh;

import memory_map.backend.auth.domain.RefreshToken;

import java.util.Objects;

public final class IssuedRefreshToken {

    private final RawRefreshToken rawToken;
    private final RefreshToken refreshToken;

    public IssuedRefreshToken(
            RawRefreshToken rawToken,
            RefreshToken refreshToken
    ) {
        this.rawToken = Objects.requireNonNull(
                rawToken,
                "rawToken must not be null"
        );
        this.refreshToken = Objects.requireNonNull(
                refreshToken,
                "refreshToken must not be null"
        );
    }

    public RawRefreshToken rawToken() {
        return rawToken;
    }

    public RefreshToken refreshToken() {
        return refreshToken;
    }

    @Override
    public boolean equals(Object other) {
        if (this == other) {
            return true;
        }

        if (!(other instanceof IssuedRefreshToken that)) {
            return false;
        }

        return rawToken.equals(that.rawToken)
                && refreshToken.equals(that.refreshToken);
    }

    @Override
    public int hashCode() {
        return Objects.hash(
                rawToken,
                refreshToken
        );
    }

    @Override
    public String toString() {
        return "IssuedRefreshToken[REDACTED]";
    }
}
