package memory_map.backend.invite.application;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.storyparticipant.domain.StoryRole;

import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

public record CreateInviteCommand(

        AuthenticatedUser authenticatedUser,

        UUID storyId,

        UUID inviteId,

        StoryRole targetRole,

        Instant currentTime

) {
    public CreateInviteCommand {
        Objects.requireNonNull(
                authenticatedUser,
                "authenticatedUser must not be null"
        );
        Objects.requireNonNull(storyId, "storyId must not be null");
        Objects.requireNonNull(inviteId, "inviteId must not be null");
        Objects.requireNonNull(targetRole, "targetRole must not be null");
        Objects.requireNonNull(currentTime, "currentTime must not be null");

        if (targetRole == StoryRole.OWNER) {
            throw new IllegalArgumentException(
                    "targetRole must not be OWNER"
            );
        }
    }

    @Override
    public String toString() {
        return "CreateInviteCommand["
                + "authenticatedUser=<redacted>, "
                + "storyId=<redacted>, "
                + "inviteId=<redacted>, "
                + "targetRole=<redacted>, "
                + "currentTime=" + currentTime
                + "]";
    }
}
