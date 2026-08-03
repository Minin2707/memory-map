package memory_map.backend.story.application;

import memory_map.backend.storyparticipant.domain.StoryRole;

import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

public record StoryParticipantView(

        UUID userId,

        String displayName,

        String avatarUrl,

        StoryRole role,

        Instant joinedAt

) {

    public StoryParticipantView {
        Objects.requireNonNull(userId, "userId must not be null");
        Objects.requireNonNull(displayName, "displayName must not be null");
        Objects.requireNonNull(role, "role must not be null");
        Objects.requireNonNull(joinedAt, "joinedAt must not be null");

        if (displayName.isBlank()) {
            throw new IllegalArgumentException("displayName must not be blank");
        }
    }
}
