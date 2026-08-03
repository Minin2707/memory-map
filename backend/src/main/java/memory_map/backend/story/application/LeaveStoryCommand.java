package memory_map.backend.story.application;

import memory_map.backend.auth.domain.AuthenticatedUser;

import java.util.Objects;
import java.util.UUID;

public record LeaveStoryCommand(

        AuthenticatedUser authenticatedUser,

        UUID storyId

) {
    public LeaveStoryCommand {
        Objects.requireNonNull(
                authenticatedUser,
                "authenticatedUser must not be null"
        );
        Objects.requireNonNull(storyId, "storyId must not be null");
    }

    @Override
    public String toString() {
        return "LeaveStoryCommand["
                + "authenticatedUser=<redacted>, "
                + "storyId=<redacted>"
                + "]";
    }
}
