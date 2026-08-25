package memory_map.backend.music.application;

import memory_map.backend.auth.domain.AuthenticatedUser;

import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

public record SetStorySoundtrackCommand(

        AuthenticatedUser authenticatedUser,

        UUID storyId,

        UUID musicTrackId,

        Instant currentTime

) {
    public SetStorySoundtrackCommand {
        Objects.requireNonNull(
                authenticatedUser,
                "authenticatedUser must not be null"
        );
        Objects.requireNonNull(storyId, "storyId must not be null");
        Objects.requireNonNull(musicTrackId, "musicTrackId must not be null");
        Objects.requireNonNull(currentTime, "currentTime must not be null");
    }

    @Override
    public String toString() {
        return "SetStorySoundtrackCommand["
                + "authenticatedUser=<redacted>, "
                + "storyId=<redacted>, "
                + "musicTrackId=<redacted>, "
                + "currentTime=" + currentTime
                + "]";
    }
}
