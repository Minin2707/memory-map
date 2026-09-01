package memory_map.backend.notification.application;

import memory_map.backend.auth.domain.AuthenticatedUser;

import java.time.Instant;

public interface MarkAllNotificationsReadUseCase {

    void markAllRead(AuthenticatedUser authenticatedUser, Instant readAt);
}
