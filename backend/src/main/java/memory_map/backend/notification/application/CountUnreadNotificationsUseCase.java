package memory_map.backend.notification.application;

import memory_map.backend.auth.domain.AuthenticatedUser;

public interface CountUnreadNotificationsUseCase {

    long countUnread(AuthenticatedUser authenticatedUser);
}
