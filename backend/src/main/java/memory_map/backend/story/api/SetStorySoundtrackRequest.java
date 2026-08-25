package memory_map.backend.story.api;

import jakarta.validation.constraints.NotNull;
import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.music.application.SetStorySoundtrackCommand;

import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

public record SetStorySoundtrackRequest(

        @NotNull
        UUID musicTrackId

) {
    public SetStorySoundtrackRequest {
        Objects.requireNonNull(musicTrackId, "musicTrackId must not be null");
    }

    public SetStorySoundtrackCommand toCommand(
            AuthenticatedUser authenticatedUser,
            UUID storyId,
            Instant currentTime
    ) {
        return new SetStorySoundtrackCommand(
                authenticatedUser,
                storyId,
                musicTrackId,
                currentTime
        );
    }
}
