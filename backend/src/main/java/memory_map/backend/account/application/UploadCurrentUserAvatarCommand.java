package memory_map.backend.account.application;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.media.image.ImageProcessingInput;

import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

public record UploadCurrentUserAvatarCommand(

        AuthenticatedUser authenticatedUser,

        UUID avatarObjectId,

        ImageProcessingInput image,

        Instant currentTime

) {
    public UploadCurrentUserAvatarCommand {
        Objects.requireNonNull(
                authenticatedUser,
                "authenticatedUser must not be null"
        );
        Objects.requireNonNull(
                avatarObjectId,
                "avatarObjectId must not be null"
        );
        Objects.requireNonNull(image, "image must not be null");
        Objects.requireNonNull(currentTime, "currentTime must not be null");
    }
}
