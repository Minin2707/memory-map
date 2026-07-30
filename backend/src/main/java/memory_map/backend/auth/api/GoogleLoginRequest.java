package memory_map.backend.auth.api;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.validation.constraints.NotBlank;

import java.util.Objects;

public final class GoogleLoginRequest {

    @NotBlank
    @JsonProperty("idToken")
    private final String idToken;

    @JsonCreator
    public GoogleLoginRequest(
            @JsonProperty("idToken") String idToken
    ) {
        this.idToken = idToken;
    }

    public String idToken() {
        return idToken;
    }

    @Override
    public boolean equals(Object other) {
        if (this == other) {
            return true;
        }

        if (!(other instanceof GoogleLoginRequest that)) {
            return false;
        }

        return Objects.equals(idToken, that.idToken);
    }

    @Override
    public int hashCode() {
        return Objects.hash(idToken);
    }

    @Override
    public String toString() {
        return "GoogleLoginRequest[REDACTED]";
    }
}
