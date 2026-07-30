package memory_map.backend.auth.login;

import memory_map.backend.auth.refresh.RawRefreshToken;
import memory_map.backend.user.domain.User;

import java.util.Objects;

public final class GoogleLoginResult {

    private final User user;
    private final String accessToken;
    private final RawRefreshToken refreshToken;

    public GoogleLoginResult(
            User user,
            String accessToken,
            RawRefreshToken refreshToken
    ) {
        this.user = Objects.requireNonNull(
                user,
                "user must not be null"
        );
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

    public User user() {
        return user;
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

        if (!(other instanceof GoogleLoginResult that)) {
            return false;
        }

        return user.equals(that.user)
                && accessToken.equals(that.accessToken)
                && refreshToken.equals(that.refreshToken);
    }

    @Override
    public int hashCode() {
        return Objects.hash(
                user,
                accessToken,
                refreshToken
        );
    }

    @Override
    public String toString() {
        return "GoogleLoginResult[REDACTED]";
    }
}
