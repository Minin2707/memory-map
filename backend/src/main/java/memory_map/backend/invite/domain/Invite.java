package memory_map.backend.invite.domain;

import memory_map.backend.storyparticipant.domain.StoryRole;

import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

public record Invite(

        UUID id,

        UUID storyId,

        StoryRole role,

        String tokenHash,

        UUID createdBy,

        Instant createdAt,

        Instant expiresAt,

        Instant usedAt

) {
    public Invite {
        Objects.requireNonNull(id, "id must not be null");
        Objects.requireNonNull(storyId, "storyId must not be null");
        Objects.requireNonNull(role, "role must not be null");
        Objects.requireNonNull(tokenHash, "tokenHash must not be null");
        Objects.requireNonNull(createdBy, "createdBy must not be null");
        Objects.requireNonNull(createdAt, "createdAt must not be null");
        Objects.requireNonNull(expiresAt, "expiresAt must not be null");

        if (role == StoryRole.OWNER) {
            throw new IllegalArgumentException("role must not be OWNER");
        }

        if (tokenHash.isBlank()) {
            throw new IllegalArgumentException("tokenHash must not be blank");
        }

        if (!expiresAt.isAfter(createdAt)) {
            throw new IllegalArgumentException("expiresAt must be after createdAt");
        }

        if (usedAt != null && usedAt.isBefore(createdAt)) {
            throw new IllegalArgumentException("usedAt must not be before createdAt");
        }
    }
}
