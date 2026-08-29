package memory_map.backend.auth.api;

import memory_map.backend.user.domain.User;

import java.util.UUID;

public record AuthUserResponse(

        UUID id,

        String displayName,

        String avatarUrl,

        boolean hasCustomAvatar

) {

    public static AuthUserResponse from(User user) {
        return new AuthUserResponse(
                user.id(),
                user.displayName(),
                effectiveAvatarUrl(user),
                user.hasCustomAvatar()
        );
    }

    private static String effectiveAvatarUrl(User user) {
        if (!user.hasCustomAvatar()) {
            return user.avatarUrl();
        }

        return "/api/v1/me/avatar/%d".formatted(
                user.customAvatarUpdatedAt().toEpochMilli()
        );
    }
}
