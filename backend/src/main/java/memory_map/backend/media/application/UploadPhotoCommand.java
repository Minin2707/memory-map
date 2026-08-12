package memory_map.backend.media.application;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.media.image.ImageProcessingInput;

import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

public record UploadPhotoCommand(

        AuthenticatedUser authenticatedUser,

        UUID memoryId,

        UUID mediaId,

        ImageProcessingInput image,

        Instant currentTime

) {
    public UploadPhotoCommand {
        Objects.requireNonNull(
                authenticatedUser,
                "authenticatedUser must not be null"
        );
        Objects.requireNonNull(memoryId, "memoryId must not be null");
        Objects.requireNonNull(mediaId, "mediaId must not be null");
        Objects.requireNonNull(image, "image must not be null");
        Objects.requireNonNull(currentTime, "currentTime must not be null");
    }

    @Override
    public String toString() {
        return "UploadPhotoCommand[hasImage=true]";
    }
}
