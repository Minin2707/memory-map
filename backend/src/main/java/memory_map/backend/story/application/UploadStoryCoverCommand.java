package memory_map.backend.story.application;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.media.image.ImageProcessingInput;

import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

public record UploadStoryCoverCommand(

        AuthenticatedUser authenticatedUser,

        UUID storyId,

        UUID coverObjectId,

        ImageProcessingInput image,

        Instant currentTime

) {
    public UploadStoryCoverCommand {
        Objects.requireNonNull(
                authenticatedUser,
                "authenticatedUser must not be null"
        );
        Objects.requireNonNull(storyId, "storyId must not be null");
        Objects.requireNonNull(
                coverObjectId,
                "coverObjectId must not be null"
        );
        Objects.requireNonNull(image, "image must not be null");
        Objects.requireNonNull(currentTime, "currentTime must not be null");
    }

    @Override
    public String toString() {
        return "UploadStoryCoverCommand[authenticatedUser=<redacted>, "
                + "storyId=<redacted>, coverObjectId=<redacted>, "
                + "hasImage=true, currentTime=" + currentTime + "]";
    }
}
