package memory_map.backend.invite.application;

import memory_map.backend.auth.domain.AuthenticatedUser;

import java.time.Instant;
import java.util.Objects;

public record AcceptInviteCommand(

        AuthenticatedUser authenticatedUser,

        String rawInviteToken,

        Instant currentTime

) {
    public AcceptInviteCommand {
        Objects.requireNonNull(
                authenticatedUser,
                "authenticatedUser must not be null"
        );
        Objects.requireNonNull(
                rawInviteToken,
                "rawInviteToken must not be null"
        );
        Objects.requireNonNull(currentTime, "currentTime must not be null");

        if (rawInviteToken.isBlank()) {
            throw new IllegalArgumentException(
                    "rawInviteToken must not be blank"
            );
        }
    }

    @Override
    public String toString() {
        return "AcceptInviteCommand["
                + "authenticatedUser=<redacted>, "
                + "rawInviteToken=<redacted>, "
                + "currentTime=" + currentTime
                + "]";
    }
}
