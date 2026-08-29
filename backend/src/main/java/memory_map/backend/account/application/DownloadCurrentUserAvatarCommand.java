package memory_map.backend.account.application;

import memory_map.backend.auth.domain.AuthenticatedUser;

import java.util.Objects;

public record DownloadCurrentUserAvatarCommand(

        AuthenticatedUser authenticatedUser

) {
    public DownloadCurrentUserAvatarCommand {
        Objects.requireNonNull(
                authenticatedUser,
                "authenticatedUser must not be null"
        );
    }
}
