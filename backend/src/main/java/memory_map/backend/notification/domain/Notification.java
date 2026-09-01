package memory_map.backend.notification.domain;

import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

public record Notification(

        UUID id,

        UUID recipientUserId,

        NotificationType type,

        UUID actorUserId,

        UUID storyId,

        UUID memoryId,

        Instant createdAt,

        Instant readAt

) {
    public Notification {
        Objects.requireNonNull(id, "id must not be null");
        Objects.requireNonNull(
                recipientUserId,
                "recipientUserId must not be null"
        );
        Objects.requireNonNull(type, "type must not be null");
        Objects.requireNonNull(actorUserId, "actorUserId must not be null");
        Objects.requireNonNull(storyId, "storyId must not be null");
        Objects.requireNonNull(createdAt, "createdAt must not be null");

        if (recipientUserId.equals(actorUserId)) {
            throw new IllegalArgumentException(
                    "recipientUserId and actorUserId must differ"
            );
        }

        if (type == NotificationType.PARTICIPANT_JOINED
                && memoryId != null) {
            throw new IllegalArgumentException(
                    "PARTICIPANT_JOINED notification must not reference memory"
            );
        }

        if (type != NotificationType.PARTICIPANT_JOINED
                && memoryId == null) {
            throw new NullPointerException(
                    "memoryId must not be null for memory notifications"
            );
        }

        if (readAt != null && readAt.isBefore(createdAt)) {
            throw new IllegalArgumentException(
                    "readAt must not be before createdAt"
            );
        }
    }
}
