package memory_map.backend.notification.application;

import memory_map.backend.auth.domain.AuthenticatedUser;

import java.time.Instant;
import java.util.UUID;

public interface MarkNotificationReadUseCase {

    void markRead(
            AuthenticatedUser authenticatedUser,
            UUID notificationId,
            Instant readAt
    );
}
