package memory_map.backend.auth.api;

import memory_map.backend.auth.login.GoogleLoginResult;

public record GoogleLoginResponse(

        AuthUserResponse user,

        String accessToken,

        String refreshToken

) {

    public static GoogleLoginResponse from(GoogleLoginResult result) {
        return new GoogleLoginResponse(
                AuthUserResponse.from(result.user()),
                result.accessToken(),
                result.refreshToken().value()
        );
    }
}
