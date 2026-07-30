package memory_map.backend.auth.api;

public record AuthTokenResponse(

        String accessToken,

        String refreshToken

) {
}
