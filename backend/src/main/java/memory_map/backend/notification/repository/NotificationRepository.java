package memory_map.backend.notification.repository;

import memory_map.backend.notification.application.NotificationReadModel;
import memory_map.backend.notification.domain.Notification;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

public interface NotificationRepository {

    void save(Notification notification);

    List<NotificationReadModel> findByRecipientUserId(
            UUID recipientUserId,
            int limit
    );

    long countUnreadByRecipientUserId(UUID recipientUserId);

    boolean markRead(UUID recipientUserId, UUID notificationId, Instant readAt);

    void markAllRead(UUID recipientUserId, Instant readAt);
}
