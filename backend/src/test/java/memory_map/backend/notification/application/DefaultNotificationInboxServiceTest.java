package memory_map.backend.notification.application;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.notification.domain.Notification;
import memory_map.backend.notification.domain.NotificationType;
import memory_map.backend.notification.repository.NotificationRepository;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class DefaultNotificationInboxServiceTest {

    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID ACTOR_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000002");
    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000011");
    private static final UUID MEMORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000021");
    private static final UUID NOTIFICATION_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000031");
    private static final Instant CURRENT_TIME =
            Instant.parse("2026-01-10T10:00:00Z");

    private final FakeNotificationRepository notificationRepository =
            new FakeNotificationRepository();
    private final DefaultNotificationInboxService service =
            new DefaultNotificationInboxService(notificationRepository);

    @Test
    void shouldListCurrentUserNotifications() {
        NotificationReadModel notification = notification();
        notificationRepository.notifications = List.of(notification);

        List<NotificationReadModel> notifications = service.listNotifications(
                new AuthenticatedUser(USER_ID),
                25
        );

        assertThat(notifications).containsExactly(notification);
        assertThat(notificationRepository.receivedRecipientUserId)
                .isEqualTo(USER_ID);
        assertThat(notificationRepository.receivedLimit).isEqualTo(25);
    }

    @Test
    void shouldCountUnreadForCurrentUser() {
        notificationRepository.unreadCount = 3;

        long count = service.countUnread(new AuthenticatedUser(USER_ID));

        assertThat(count).isEqualTo(3);
        assertThat(notificationRepository.receivedRecipientUserId)
                .isEqualTo(USER_ID);
    }

    @Test
    void shouldMarkCurrentUserNotificationRead() {
        notificationRepository.markReadResult = true;

        service.markRead(
                new AuthenticatedUser(USER_ID),
                NOTIFICATION_ID,
                CURRENT_TIME
        );

        assertThat(notificationRepository.receivedRecipientUserId)
                .isEqualTo(USER_ID);
        assertThat(notificationRepository.receivedNotificationId)
                .isEqualTo(NOTIFICATION_ID);
        assertThat(notificationRepository.receivedReadAt)
                .isEqualTo(CURRENT_TIME);
    }

    @Test
    void shouldRejectMarkReadWhenNotificationIsNotVisibleToCurrentUser() {
        notificationRepository.markReadResult = false;

        assertThatThrownBy(() -> service.markRead(
                new AuthenticatedUser(USER_ID),
                NOTIFICATION_ID,
                CURRENT_TIME
        ))
                .isInstanceOf(NotificationNotFoundException.class);
    }

    @Test
    void shouldMarkAllCurrentUserNotificationsRead() {
        service.markAllRead(new AuthenticatedUser(USER_ID), CURRENT_TIME);

        assertThat(notificationRepository.receivedRecipientUserId)
                .isEqualTo(USER_ID);
        assertThat(notificationRepository.receivedReadAt)
                .isEqualTo(CURRENT_TIME);
    }

    @Test
    void shouldRejectNullDependency() {
        assertThatThrownBy(() -> new DefaultNotificationInboxService(null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("notificationRepository must not be null");
    }

    private static NotificationReadModel notification() {
        return new NotificationReadModel(
                NOTIFICATION_ID,
                NotificationType.MEMORY_CREATED,
                new NotificationActorView(ACTOR_ID, "Actor User", null),
                new NotificationStoryView(STORY_ID, "Our Story"),
                new NotificationMemoryView(MEMORY_ID, "First Memory"),
                CURRENT_TIME,
                null
        );
    }

    private static final class FakeNotificationRepository
            implements NotificationRepository {

        private List<NotificationReadModel> notifications = List.of();
        private long unreadCount;
        private boolean markReadResult;
        private UUID receivedRecipientUserId;
        private UUID receivedNotificationId;
        private Instant receivedReadAt;
        private int receivedLimit;

        @Override
        public void save(Notification notification) {
            throw new UnsupportedOperationException();
        }

        @Override
        public List<NotificationReadModel> findByRecipientUserId(
                UUID recipientUserId,
                int limit
        ) {
            receivedRecipientUserId = recipientUserId;
            receivedLimit = limit;

            return notifications;
        }

        @Override
        public long countUnreadByRecipientUserId(UUID recipientUserId) {
            receivedRecipientUserId = recipientUserId;

            return unreadCount;
        }

        @Override
        public boolean markRead(
                UUID recipientUserId,
                UUID notificationId,
                Instant readAt
        ) {
            receivedRecipientUserId = recipientUserId;
            receivedNotificationId = notificationId;
            receivedReadAt = readAt;

            return markReadResult;
        }

        @Override
        public void markAllRead(UUID recipientUserId, Instant readAt) {
            receivedRecipientUserId = recipientUserId;
            receivedReadAt = readAt;
        }
    }
}
