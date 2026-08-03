package memory_map.backend.invite.application;

import memory_map.backend.auth.domain.AuthenticatedUser;

import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

public record CreateInviteCommand(

        AuthenticatedUser authenticatedUser,

        UUID storyId,

        UUID inviteId,

        Instant currentTime

) {
    public CreateInviteCommand {
        Objects.requireNonNull(
                authenticatedUser,
                "authenticatedUser must not be null"
        );
        Objects.requireNonNull(storyId, "storyId must not be null");
        Objects.requireNonNull(inviteId, "inviteId must not be null");
        Objects.requireNonNull(currentTime, "currentTime must not be null");
    }

    @Override
    public String toString() {
        return "CreateInviteCommand["
                + "authenticatedUser=<redacted>, "
                + "storyId=<redacted>, "
                + "inviteId=<redacted>, "
                + "currentTime=" + currentTime
                + "]";
    }
}
