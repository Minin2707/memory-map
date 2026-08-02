package memory_map.backend.story.application;

import memory_map.backend.auth.domain.AuthenticatedUser;

import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

public record UpdateStoryCommand(

        AuthenticatedUser authenticatedUser,

        UUID storyId,

        UpdateStoryField<String> title,

        UpdateStoryField<String> description,

        Instant currentTime

) {
    public UpdateStoryCommand {
        Objects.requireNonNull(
                authenticatedUser,
                "authenticatedUser must not be null"
        );
        Objects.requireNonNull(storyId, "storyId must not be null");
        Objects.requireNonNull(title, "title must not be null");
        Objects.requireNonNull(
                description,
                "description must not be null"
        );
        Objects.requireNonNull(currentTime, "currentTime must not be null");

        if (!title.isProvided() && !description.isProvided()) {
            throw new IllegalArgumentException(
                    "at least one update field must be provided"
            );
        }

        if (title.isProvided()) {
            Objects.requireNonNull(
                    title.value(),
                    "title value must not be null"
            );

            if (title.value().isBlank()) {
                throw new IllegalArgumentException(
                        "title value must not be blank"
                );
            }
        }
    }

    @Override
    public String toString() {
        return "UpdateStoryCommand["
                + "authenticatedUser=<redacted>, "
                + "storyId=<redacted>, "
                + "title=" + fieldState(title) + ", "
                + "description=" + fieldState(description) + ", "
                + "currentTime=" + currentTime
                + "]";
    }

    private static String fieldState(UpdateStoryField<?> field) {
        if (field.isProvided()) {
            return "provided";
        }

        return "notProvided";
    }
}
