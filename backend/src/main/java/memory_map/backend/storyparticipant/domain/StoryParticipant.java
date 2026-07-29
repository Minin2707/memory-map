package memory_map.backend.storyparticipant.domain;

import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

public record StoryParticipant(

        UUID storyId,
        UUID userId,
        StoryRole role,
        Instant joinedAt

) {

    public StoryParticipant {
        Objects.requireNonNull(storyId, "storyId must not be null");
        Objects.requireNonNull(userId, "userId must not be null");
        Objects.requireNonNull(role, "role must not be null");
        Objects.requireNonNull(joinedAt, "joinedAt must not be null");
    }

}
