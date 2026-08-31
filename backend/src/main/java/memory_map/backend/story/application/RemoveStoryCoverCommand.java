package memory_map.backend.story.application;

import memory_map.backend.auth.domain.AuthenticatedUser;

import java.util.Objects;
import java.util.UUID;

public record RemoveStoryCoverCommand(

        AuthenticatedUser authenticatedUser,

        UUID storyId

) {
    public RemoveStoryCoverCommand {
        Objects.requireNonNull(
                authenticatedUser,
                "authenticatedUser must not be null"
        );
        Objects.requireNonNull(storyId, "storyId must not be null");
    }

    @Override
    public String toString() {
        return "RemoveStoryCoverCommand[authenticatedUser=<redacted>, "
                + "storyId=<redacted>]";
    }
}
