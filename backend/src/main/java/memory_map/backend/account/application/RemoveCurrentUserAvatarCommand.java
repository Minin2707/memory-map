package memory_map.backend.account.application;

import memory_map.backend.auth.domain.AuthenticatedUser;

import java.time.Instant;
import java.util.Objects;

public record RemoveCurrentUserAvatarCommand(

        AuthenticatedUser authenticatedUser,

        Instant currentTime

) {
    public RemoveCurrentUserAvatarCommand {
        Objects.requireNonNull(
                authenticatedUser,
                "authenticatedUser must not be null"
        );
        Objects.requireNonNull(currentTime, "currentTime must not be null");
    }
}
