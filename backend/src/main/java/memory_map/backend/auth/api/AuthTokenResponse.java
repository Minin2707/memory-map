package memory_map.backend.auth.api;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonProperty;

import java.util.Objects;

public final class AuthTokenResponse {

    @JsonProperty("accessToken")
    private final String accessToken;

    @JsonProperty("refreshToken")
    private final String refreshToken;

    @JsonCreator
    public AuthTokenResponse(
            @JsonProperty("accessToken") String accessToken,
            @JsonProperty("refreshToken") String refreshToken
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

        if (refreshToken.isBlank()) {
            throw new IllegalArgumentException(
                    "refreshToken must not be blank"
            );
        }
    }

    public String accessToken() {
        return accessToken;
    }

    public String refreshToken() {
        return refreshToken;
    }

    @Override
    public boolean equals(Object other) {
        if (this == other) {
            return true;
        }

        if (!(other instanceof AuthTokenResponse that)) {
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
        return "AuthTokenResponse[REDACTED]";
    }
}
