package memory_map.backend.notification.api;

import memory_map.backend.notification.application.NotificationActorView;

import java.util.UUID;

public record NotificationActorResponse(

        UUID userId,

        String displayName,

        String avatarUrl

) {
    static NotificationActorResponse from(NotificationActorView actor) {
        return new NotificationActorResponse(
                actor.userId(),
                actor.displayName(),
                actor.avatarUrl()
        );
    }
}
