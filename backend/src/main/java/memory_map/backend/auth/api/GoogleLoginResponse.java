package memory_map.backend.auth.api;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonProperty;
import memory_map.backend.auth.login.GoogleLoginResult;

import java.util.Objects;

public final class GoogleLoginResponse {

    @JsonProperty("user")
    private final AuthUserResponse user;

    @JsonProperty("accessToken")
    private final String accessToken;

    @JsonProperty("refreshToken")
    private final String refreshToken;

    @JsonCreator
    public GoogleLoginResponse(
            @JsonProperty("user") AuthUserResponse user,
            @JsonProperty("accessToken") String accessToken,
            @JsonProperty("refreshToken") String refreshToken
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

        if (refreshToken.isBlank()) {
            throw new IllegalArgumentException(
                    "refreshToken must not be blank"
            );
        }
    }

    public static GoogleLoginResponse from(GoogleLoginResult result) {
        return new GoogleLoginResponse(
                AuthUserResponse.from(result.user()),
                result.accessToken(),
                result.refreshToken().value()
        );
    }

    public AuthUserResponse user() {
        return user;
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

        if (!(other instanceof GoogleLoginResponse that)) {
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
        return "GoogleLoginResponse[REDACTED]";
    }
}
