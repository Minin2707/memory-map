package memory_map.backend.auth.api;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.validation.constraints.NotBlank;

import java.util.Objects;

public final class RefreshTokenRequest {

    @NotBlank
    @JsonProperty("refreshToken")
    private final String refreshToken;

    @JsonCreator
    public RefreshTokenRequest(
            @JsonProperty("refreshToken") String refreshToken
    ) {
        this.refreshToken = refreshToken;
    }

    public String refreshToken() {
        return refreshToken;
    }

    @Override
    public boolean equals(Object other) {
        if (this == other) {
            return true;
        }

        if (!(other instanceof RefreshTokenRequest that)) {
            return false;
        }

        return Objects.equals(refreshToken, that.refreshToken);
    }

    @Override
    public int hashCode() {
        return Objects.hash(refreshToken);
    }

    @Override
    public String toString() {
        return "RefreshTokenRequest[REDACTED]";
    }
}
