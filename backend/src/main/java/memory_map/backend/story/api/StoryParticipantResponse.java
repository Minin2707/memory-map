package memory_map.backend.story.api;

import memory_map.backend.story.application.StoryParticipantView;
import memory_map.backend.storyparticipant.domain.StoryRole;

import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

public record StoryParticipantResponse(

        UUID userId,

        String displayName,

        String avatarUrl,

        StoryRole role,

        Instant joinedAt

) {
    public static StoryParticipantResponse from(
            StoryParticipantView participant
    ) {
        Objects.requireNonNull(
                participant,
                "participant must not be null"
        );

        return new StoryParticipantResponse(
                participant.userId(),
                participant.displayName(),
                participant.avatarUrl(),
                participant.role(),
                participant.joinedAt()
        );
    }
}
