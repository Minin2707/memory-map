package memory_map.backend.notification.application;

import java.util.Objects;
import java.util.UUID;

public record NotificationActorView(

        UUID userId,

        String displayName,

        String avatarUrl

) {
    public NotificationActorView {
        Objects.requireNonNull(userId, "userId must not be null");
        Objects.requireNonNull(displayName, "displayName must not be null");

        if (displayName.isBlank()) {
            throw new IllegalArgumentException("displayName must not be blank");
        }
    }
}
