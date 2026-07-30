package memory_map.backend.auth.api;

import jakarta.validation.constraints.NotBlank;

public record GoogleLoginRequest(

        @NotBlank
        String idToken

) {
}
