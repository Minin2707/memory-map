package memory_map.backend.notification.application;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.notification.repository.NotificationRepository;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;
import java.util.Objects;
import java.util.UUID;

public class DefaultNotificationInboxService
        implements ListNotificationsUseCase,
        CountUnreadNotificationsUseCase,
        MarkNotificationReadUseCase,
        MarkAllNotificationsReadUseCase {

    private final NotificationRepository notificationRepository;

    public DefaultNotificationInboxService(
            NotificationRepository notificationRepository
    ) {
        this.notificationRepository = Objects.requireNonNull(
                notificationRepository,
                "notificationRepository must not be null"
        );
    }

    @Override
    @Transactional(readOnly = true)
    public List<NotificationReadModel> listNotifications(
            AuthenticatedUser authenticatedUser,
            int limit
    ) {
        Objects.requireNonNull(
                authenticatedUser,
                "authenticatedUser must not be null"
        );

        return notificationRepository.findByRecipientUserId(
                authenticatedUser.userId(),
                limit
        );
    }

    @Override
    @Transactional(readOnly = true)
    public long countUnread(AuthenticatedUser authenticatedUser) {
        Objects.requireNonNull(
                authenticatedUser,
                "authenticatedUser must not be null"
        );

        return notificationRepository.countUnreadByRecipientUserId(
                authenticatedUser.userId()
        );
    }

    @Override
    @Transactional
    public void markRead(
            AuthenticatedUser authenticatedUser,
            UUID notificationId,
            Instant readAt
    ) {
        Objects.requireNonNull(
                authenticatedUser,
                "authenticatedUser must not be null"
        );
        Objects.requireNonNull(notificationId, "notificationId must not be null");
        Objects.requireNonNull(readAt, "readAt must not be null");

        boolean marked = notificationRepository.markRead(
                authenticatedUser.userId(),
                notificationId,
                readAt
        );

        if (!marked) {
            throw new NotificationNotFoundException();
        }
    }

    @Override
    @Transactional
    public void markAllRead(
            AuthenticatedUser authenticatedUser,
            Instant readAt
    ) {
        Objects.requireNonNull(
                authenticatedUser,
                "authenticatedUser must not be null"
        );
        Objects.requireNonNull(readAt, "readAt must not be null");

        notificationRepository.markAllRead(
                authenticatedUser.userId(),
                readAt
        );
    }
}
