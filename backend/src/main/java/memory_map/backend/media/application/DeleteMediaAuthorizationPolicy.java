package memory_map.backend.media.application;

import memory_map.backend.memory.domain.Memory;
import memory_map.backend.storyparticipant.domain.StoryParticipant;
import memory_map.backend.storyparticipant.domain.StoryRole;

import java.util.Objects;
import java.util.UUID;

public final class DeleteMediaAuthorizationPolicy {

    public DeleteMediaAuthorizationPolicy() {
    }

    public boolean canDeleteMedia(
            StoryParticipant participant,
            Memory memory,
            UUID requesterUserId
    ) {
        Objects.requireNonNull(participant, "participant must not be null");
        Objects.requireNonNull(memory, "memory must not be null");
        Objects.requireNonNull(
                requesterUserId,
                "requesterUserId must not be null"
        );

        if (!participant.storyId().equals(memory.storyId())) {
            return false;
        }

        if (!participant.userId().equals(requesterUserId)) {
            return false;
        }

        StoryRole role = participant.role();

        return role == StoryRole.OWNER
                || role == StoryRole.CO_OWNER
                || memory.createdBy().equals(requesterUserId);
    }
}
