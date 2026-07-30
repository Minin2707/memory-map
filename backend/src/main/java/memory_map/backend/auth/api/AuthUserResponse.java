package memory_map.backend.auth.api;

import memory_map.backend.user.domain.User;

import java.util.UUID;

public record AuthUserResponse(

        UUID id,

        String displayName,

        String avatarUrl

) {

    public static AuthUserResponse from(User user) {
        return new AuthUserResponse(
                user.id(),
                user.displayName(),
                user.avatarUrl()
        );
    }
}
