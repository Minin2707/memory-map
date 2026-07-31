package memory_map.backend.story.application;

import memory_map.backend.auth.domain.AuthenticatedUser;

import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

public record CreateStoryCommand(

        AuthenticatedUser authenticatedUser,

        UUID storyId,

        String title,

        String description,

        Instant currentTime

) {
    public CreateStoryCommand {
        Objects.requireNonNull(
                authenticatedUser,
                "authenticatedUser must not be null"
        );
        Objects.requireNonNull(storyId, "storyId must not be null");
        Objects.requireNonNull(title, "title must not be null");
        Objects.requireNonNull(currentTime, "currentTime must not be null");

        if (title.isBlank()) {
            throw new IllegalArgumentException("title must not be blank");
        }
    }
}
