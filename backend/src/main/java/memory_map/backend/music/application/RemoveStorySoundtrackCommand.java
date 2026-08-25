package memory_map.backend.music.application;

import memory_map.backend.auth.domain.AuthenticatedUser;

import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

public record RemoveStorySoundtrackCommand(

        AuthenticatedUser authenticatedUser,

        UUID storyId,

        Instant currentTime

) {
    public RemoveStorySoundtrackCommand {
        Objects.requireNonNull(
                authenticatedUser,
                "authenticatedUser must not be null"
        );
        Objects.requireNonNull(storyId, "storyId must not be null");
        Objects.requireNonNull(currentTime, "currentTime must not be null");
    }

    @Override
    public String toString() {
        return "RemoveStorySoundtrackCommand["
                + "authenticatedUser=<redacted>, "
                + "storyId=<redacted>, "
                + "currentTime=" + currentTime
                + "]";
    }
}
