package memory_map.backend.account.application;

import memory_map.backend.auth.domain.AuthenticatedUser;

import java.time.Instant;
import java.util.Objects;

public record UpdateCurrentUserDisplayNameCommand(

        AuthenticatedUser authenticatedUser,

        String displayName,

        Instant currentTime

) {
    public UpdateCurrentUserDisplayNameCommand {
        Objects.requireNonNull(
                authenticatedUser,
                "authenticatedUser must not be null"
        );
        Objects.requireNonNull(displayName, "displayName must not be null");
        Objects.requireNonNull(currentTime, "currentTime must not be null");
    }
}
