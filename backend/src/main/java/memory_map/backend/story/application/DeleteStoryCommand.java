package memory_map.backend.story.application;

import memory_map.backend.auth.domain.AuthenticatedUser;

import java.util.Objects;
import java.util.UUID;

public record DeleteStoryCommand(

        AuthenticatedUser authenticatedUser,

        UUID storyId

) {
    public DeleteStoryCommand {
        Objects.requireNonNull(
                authenticatedUser,
                "authenticatedUser must not be null"
        );
        Objects.requireNonNull(storyId, "storyId must not be null");
    }

    @Override
    public String toString() {
        return "DeleteStoryCommand["
                + "authenticatedUser=<redacted>, "
                + "storyId=<redacted>"
                + "]";
    }
}
