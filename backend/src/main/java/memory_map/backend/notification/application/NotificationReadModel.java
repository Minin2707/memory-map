package memory_map.backend.notification.application;

import memory_map.backend.notification.domain.NotificationType;

import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

public record NotificationReadModel(

        UUID id,

        NotificationType type,

        NotificationActorView actor,

        NotificationStoryView story,

        NotificationMemoryView memory,

        Instant createdAt,

        Instant readAt

) {
    public NotificationReadModel {
        Objects.requireNonNull(id, "id must not be null");
        Objects.requireNonNull(type, "type must not be null");
        Objects.requireNonNull(actor, "actor must not be null");
        Objects.requireNonNull(story, "story must not be null");
        Objects.requireNonNull(createdAt, "createdAt must not be null");
    }

    public boolean read() {
        return readAt != null;
    }
}
