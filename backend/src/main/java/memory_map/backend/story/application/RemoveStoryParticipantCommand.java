package memory_map.backend.story.application;

import memory_map.backend.auth.domain.AuthenticatedUser;

import java.util.Objects;
import java.util.UUID;

public record RemoveStoryParticipantCommand(

        AuthenticatedUser authenticatedUser,

        UUID storyId,

        UUID participantUserId

) {
    public RemoveStoryParticipantCommand {
        Objects.requireNonNull(
                authenticatedUser,
                "authenticatedUser must not be null"
        );
        Objects.requireNonNull(storyId, "storyId must not be null");
        Objects.requireNonNull(
                participantUserId,
                "participantUserId must not be null"
        );
    }

    @Override
    public String toString() {
        return "RemoveStoryParticipantCommand["
                + "authenticatedUser=<redacted>, "
                + "storyId=<redacted>, "
                + "participantUserId=<redacted>"
                + "]";
    }
}
