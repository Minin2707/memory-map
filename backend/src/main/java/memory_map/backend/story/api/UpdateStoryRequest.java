package memory_map.backend.story.api;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.story.application.UpdateStoryCommand;
import memory_map.backend.story.application.UpdateStoryField;
import tools.jackson.databind.annotation.JsonDeserialize;

import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

@JsonDeserialize(using = UpdateStoryRequestDeserializer.class)
public record UpdateStoryRequest(

        PatchField<String> title,

        PatchField<String> description

) {
    public UpdateStoryRequest {
        Objects.requireNonNull(title, "title must not be null");
        Objects.requireNonNull(
                description,
                "description must not be null"
        );

        if (!title.isPresent() && !description.isPresent()) {
            throw new IllegalArgumentException(
                    "at least one update field must be provided"
            );
        }

        if (title.isPresent()) {
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

    public UpdateStoryCommand toCommand(
            AuthenticatedUser authenticatedUser,
            UUID storyId,
            Instant currentTime
    ) {
        return new UpdateStoryCommand(
                authenticatedUser,
                storyId,
                toUpdateStoryField(title),
                toUpdateStoryField(description),
                currentTime
        );
    }

    private static <T> UpdateStoryField<T> toUpdateStoryField(
            PatchField<T> field
    ) {
        if (field.isPresent()) {
            return UpdateStoryField.provided(field.value());
        }

        return UpdateStoryField.notProvided();
    }
}
