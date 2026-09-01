package memory_map.backend.notification.api;

import memory_map.backend.notification.application.NotificationReadModel;
import memory_map.backend.notification.domain.NotificationType;

import java.time.Instant;
import java.util.UUID;

public record NotificationResponse(

        UUID id,

        NotificationType type,

        NotificationActorResponse actor,

        NotificationStoryResponse story,

        NotificationMemoryResponse memory,

        Instant createdAt,

        boolean read

) {
    static NotificationResponse from(NotificationReadModel notification) {
        return new NotificationResponse(
                notification.id(),
                notification.type(),
                NotificationActorResponse.from(notification.actor()),
                NotificationStoryResponse.from(notification.story()),
                notification.memory() == null
                        ? null
                        : NotificationMemoryResponse.from(
                                notification.memory()
                        ),
                notification.createdAt(),
                notification.read()
        );
    }
}
