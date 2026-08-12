package memory_map.backend.media.application;

import memory_map.backend.auth.domain.AuthenticatedUser;

import java.util.Objects;
import java.util.UUID;

public record DeleteMediaCommand(

        AuthenticatedUser authenticatedUser,

        UUID mediaId

) {
    public DeleteMediaCommand {
        Objects.requireNonNull(
                authenticatedUser,
                "authenticatedUser must not be null"
        );
        Objects.requireNonNull(mediaId, "mediaId must not be null");
    }

    @Override
    public String toString() {
        return "DeleteMediaCommand()";
    }
}
