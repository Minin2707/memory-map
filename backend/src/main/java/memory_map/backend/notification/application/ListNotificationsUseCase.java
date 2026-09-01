package memory_map.backend.notification.application;

import memory_map.backend.auth.domain.AuthenticatedUser;

import java.util.List;

public interface ListNotificationsUseCase {

    List<NotificationReadModel> listNotifications(
            AuthenticatedUser authenticatedUser,
            int limit
    );
}
