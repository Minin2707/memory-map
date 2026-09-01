package memory_map.backend.notification.application;

import memory_map.backend.memory.domain.Memory;
import memory_map.backend.notification.domain.Notification;
import memory_map.backend.notification.domain.NotificationType;
import memory_map.backend.notification.repository.NotificationRepository;
import memory_map.backend.storyparticipant.domain.StoryParticipant;
import memory_map.backend.storyparticipant.domain.StoryRole;
import memory_map.backend.storyparticipant.repository.StoryParticipantRepository;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class DefaultNotificationPublisherTest {

    private static final UUID ACTOR_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID OWNER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000002");
    private static final UUID EDITOR_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000003");
    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000011");
    private static final UUID MEMORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000021");
    private static final Instant BASE_TIME =
            Instant.parse("2026-01-01T10:00:00Z");
    private static final Instant CURRENT_TIME =
            Instant.parse("2026-01-10T10:00:00Z");

    private final FakeNotificationRepository notificationRepository =
            new FakeNotificationRepository();
    private final FakeStoryParticipantRepository storyParticipantRepository =
            new FakeStoryParticipantRepository();
    private final DefaultNotificationPublisher publisher =
            new DefaultNotificationPublisher(
                    notificationRepository,
                    storyParticipantRepository
            );

    @Test
    void shouldCreateParticipantJoinedForExistingParticipantsExceptActor() {
        storyParticipantRepository.participants = List.of(
                participant(OWNER_ID, StoryRole.OWNER),
                participant(ACTOR_ID, StoryRole.CO_OWNER),
                participant(EDITOR_ID, StoryRole.EDITOR)
        );

        publisher.participantJoined(STORY_ID, ACTOR_ID, CURRENT_TIME);

        assertThat(notificationRepository.saved)
                .extracting(Notification::recipientUserId)
                .containsExactly(OWNER_ID, EDITOR_ID);
        assertThat(notificationRepository.saved)
                .allSatisfy(notification -> {
                    assertThat(notification.type())
                            .isEqualTo(NotificationType.PARTICIPANT_JOINED);
                    assertThat(notification.actorUserId()).isEqualTo(ACTOR_ID);
                    assertThat(notification.storyId()).isEqualTo(STORY_ID);
                    assertThat(notification.memoryId()).isNull();
                    assertThat(notification.createdAt())
                            .isEqualTo(CURRENT_TIME);
                    assertThat(notification.readAt()).isNull();
                });
    }

    @Test
    void shouldCreateMemoryCreatedForOtherParticipantsOnly() {
        storyParticipantRepository.participants = List.of(
                participant(ACTOR_ID, StoryRole.OWNER),
                participant(EDITOR_ID, StoryRole.EDITOR)
        );

        publisher.memoryCreated(memory(ACTOR_ID), CURRENT_TIME);

        assertThat(notificationRepository.saved).hasSize(1);
        Notification notification = notificationRepository.saved.get(0);
        assertThat(notification.recipientUserId()).isEqualTo(EDITOR_ID);
        assertThat(notification.type()).isEqualTo(NotificationType.MEMORY_CREATED);
        assertThat(notification.actorUserId()).isEqualTo(ACTOR_ID);
        assertThat(notification.storyId()).isEqualTo(STORY_ID);
        assertThat(notification.memoryId()).isEqualTo(MEMORY_ID);
    }

    @Test
    void shouldCreatePhotosAddedForOtherParticipantsOnly() {
        storyParticipantRepository.participants = List.of(
                participant(OWNER_ID, StoryRole.OWNER),
                participant(ACTOR_ID, StoryRole.CO_OWNER)
        );

        publisher.photosAdded(memory(OWNER_ID), ACTOR_ID, CURRENT_TIME);

        assertThat(notificationRepository.saved).hasSize(1);
        Notification notification = notificationRepository.saved.get(0);
        assertThat(notification.recipientUserId()).isEqualTo(OWNER_ID);
        assertThat(notification.type()).isEqualTo(NotificationType.PHOTOS_ADDED);
        assertThat(notification.actorUserId()).isEqualTo(ACTOR_ID);
        assertThat(notification.storyId()).isEqualTo(STORY_ID);
        assertThat(notification.memoryId()).isEqualTo(MEMORY_ID);
    }

    @Test
    void shouldSkipNotificationWhenActorIsOnlyParticipant() {
        storyParticipantRepository.participants = List.of(
                participant(ACTOR_ID, StoryRole.OWNER)
        );

        publisher.memoryCreated(memory(ACTOR_ID), CURRENT_TIME);

        assertThat(notificationRepository.saved).isEmpty();
    }

    @Test
    void shouldRejectNullDependencies() {
        assertThatThrownBy(() -> new DefaultNotificationPublisher(
                null,
                storyParticipantRepository
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("notificationRepository must not be null");

        assertThatThrownBy(() -> new DefaultNotificationPublisher(
                notificationRepository,
                null
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("storyParticipantRepository must not be null");
    }

    private static StoryParticipant participant(UUID userId, StoryRole role) {
        return new StoryParticipant(STORY_ID, userId, role, BASE_TIME);
    }

    private static Memory memory(UUID createdBy) {
        return new Memory(
                MEMORY_ID,
                STORY_ID,
                createdBy,
                "First day",
                "At the sea",
                "Batumi",
                41.616754,
                41.636745,
                LocalDate.of(2025, 5, 1),
                BASE_TIME,
                BASE_TIME
        );
    }

    private static final class FakeNotificationRepository
            implements NotificationRepository {

        private final List<Notification> saved = new ArrayList<>();

        @Override
        public void save(Notification notification) {
            saved.add(notification);
        }

        @Override
        public List<NotificationReadModel> findByRecipientUserId(
                UUID recipientUserId,
                int limit
        ) {
            throw new UnsupportedOperationException();
        }

        @Override
        public long countUnreadByRecipientUserId(UUID recipientUserId) {
            throw new UnsupportedOperationException();
        }

        @Override
        public boolean markRead(
                UUID recipientUserId,
                UUID notificationId,
                Instant readAt
        ) {
            throw new UnsupportedOperationException();
        }

        @Override
        public void markAllRead(UUID recipientUserId, Instant readAt) {
            throw new UnsupportedOperationException();
        }
    }

    private static final class FakeStoryParticipantRepository
            implements StoryParticipantRepository {

        private List<StoryParticipant> participants = List.of();

        @Override
        public Optional<StoryParticipant> find(UUID storyId, UUID userId) {
            throw new UnsupportedOperationException();
        }

        @Override
        public List<StoryParticipant> findByStoryId(UUID storyId) {
            return participants;
        }

        @Override
        public List<StoryParticipant> findByUserId(UUID userId) {
            throw new UnsupportedOperationException();
        }

        @Override
        public long countOwners(UUID storyId) {
            throw new UnsupportedOperationException();
        }

        @Override
        public boolean exists(UUID storyId, UUID userId) {
            throw new UnsupportedOperationException();
        }

        @Override
        public void save(StoryParticipant participant) {
            throw new UnsupportedOperationException();
        }

        @Override
        public void update(StoryParticipant participant) {
            throw new UnsupportedOperationException();
        }

        @Override
        public void delete(UUID storyId, UUID userId) {
            throw new UnsupportedOperationException();
        }
    }
}
