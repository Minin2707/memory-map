package memory_map.backend.notification.application;

import memory_map.backend.notification.domain.Notification;
import memory_map.backend.notification.repository.NotificationRepository;
import memory_map.backend.storyparticipant.domain.StoryParticipant;
import memory_map.backend.storyparticipant.repository.StoryParticipantRepository;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

class NotificationApplicationConfigurationTest {

    private final ApplicationContextRunner contextRunner =
            new ApplicationContextRunner()
                    .withUserConfiguration(
                            NotificationApplicationConfiguration.class
                    )
                    .withBean(
                            NotificationRepository.class,
                            FakeNotificationRepository::new
                    )
                    .withBean(
                            StoryParticipantRepository.class,
                            FakeStoryParticipantRepository::new
                    );

    @Test
    void shouldRegisterNotificationPublisherBean() {

        contextRunner.run(context -> {
            assertThat(context).hasSingleBean(NotificationPublisher.class);
            assertThat(context.getBean(NotificationPublisher.class))
                    .isInstanceOf(DefaultNotificationPublisher.class);
        });
    }

    @Test
    void shouldRegisterNotificationInboxUseCaseBeans() {

        contextRunner.run(context -> {
            assertThat(context)
                    .hasSingleBean(DefaultNotificationInboxService.class);
            assertThat(context).hasSingleBean(ListNotificationsUseCase.class);
            assertThat(context.getBean(ListNotificationsUseCase.class))
                    .isInstanceOf(DefaultNotificationInboxService.class);
            assertThat(context)
                    .hasSingleBean(CountUnreadNotificationsUseCase.class);
            assertThat(context.getBean(CountUnreadNotificationsUseCase.class))
                    .isInstanceOf(DefaultNotificationInboxService.class);
            assertThat(context)
                    .hasSingleBean(MarkNotificationReadUseCase.class);
            assertThat(context.getBean(MarkNotificationReadUseCase.class))
                    .isInstanceOf(DefaultNotificationInboxService.class);
            assertThat(context)
                    .hasSingleBean(MarkAllNotificationsReadUseCase.class);
            assertThat(context.getBean(MarkAllNotificationsReadUseCase.class))
                    .isInstanceOf(DefaultNotificationInboxService.class);
            DefaultNotificationInboxService inboxService =
                    context.getBean(DefaultNotificationInboxService.class);
            assertThat(context.getBean(ListNotificationsUseCase.class))
                    .isSameAs(inboxService);
            assertThat(context.getBean(CountUnreadNotificationsUseCase.class))
                    .isSameAs(inboxService);
            assertThat(context.getBean(MarkNotificationReadUseCase.class))
                    .isSameAs(inboxService);
            assertThat(context.getBean(MarkAllNotificationsReadUseCase.class))
                    .isSameAs(inboxService);
        });
    }

    private static final class FakeNotificationRepository
            implements NotificationRepository {

        @Override
        public void save(Notification notification) {
        }

        @Override
        public List<NotificationReadModel> findByRecipientUserId(
                UUID recipientUserId,
                int limit
        ) {
            return List.of();
        }

        @Override
        public long countUnreadByRecipientUserId(UUID recipientUserId) {
            return 0;
        }

        @Override
        public boolean markRead(
                UUID recipientUserId,
                UUID notificationId,
                Instant readAt
        ) {
            return false;
        }

        @Override
        public void markAllRead(UUID recipientUserId, Instant readAt) {
        }
    }

    private static final class FakeStoryParticipantRepository
            implements StoryParticipantRepository {

        @Override
        public Optional<StoryParticipant> find(UUID storyId, UUID userId) {
            return Optional.empty();
        }

        @Override
        public List<StoryParticipant> findByStoryId(UUID storyId) {
            return List.of();
        }

        @Override
        public List<StoryParticipant> findByUserId(UUID userId) {
            return List.of();
        }

        @Override
        public long countOwners(UUID storyId) {
            return 0;
        }

        @Override
        public boolean exists(UUID storyId, UUID userId) {
            return false;
        }

        @Override
        public void save(StoryParticipant participant) {
        }

        @Override
        public void update(StoryParticipant participant) {
        }

        @Override
        public void delete(UUID storyId, UUID userId) {
        }
    }
}
