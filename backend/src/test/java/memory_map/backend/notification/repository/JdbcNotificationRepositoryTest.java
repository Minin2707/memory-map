package memory_map.backend.notification.repository;

import memory_map.backend.IntegrationTest;
import memory_map.backend.memory.domain.Memory;
import memory_map.backend.memory.repository.MemoryRepository;
import memory_map.backend.notification.application.NotificationReadModel;
import memory_map.backend.notification.domain.Notification;
import memory_map.backend.notification.domain.NotificationType;
import memory_map.backend.story.domain.Story;
import memory_map.backend.story.repository.StoryRepository;
import memory_map.backend.storyparticipant.domain.StoryParticipant;
import memory_map.backend.storyparticipant.domain.StoryRole;
import memory_map.backend.storyparticipant.repository.StoryParticipantRepository;
import memory_map.backend.user.domain.User;
import memory_map.backend.user.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.simple.JdbcClient;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

class JdbcNotificationRepositoryTest extends IntegrationTest {

    @Autowired
    private NotificationRepository repository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private StoryRepository storyRepository;

    @Autowired
    private MemoryRepository memoryRepository;

    @Autowired
    private StoryParticipantRepository storyParticipantRepository;

    @Autowired
    private JdbcClient jdbcClient;

    private static final UUID RECIPIENT_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID OTHER_RECIPIENT_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000002");
    private static final UUID ACTOR_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000003");
    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000011");
    private static final UUID MEMORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000021");
    private static final UUID FIRST_NOTIFICATION_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000031");
    private static final UUID SECOND_NOTIFICATION_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000032");
    private static final UUID THIRD_NOTIFICATION_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000033");
    private static final Instant BASE_TIME =
            Instant.parse("2026-01-01T10:00:00Z");
    private static final Instant CURRENT_TIME =
            Instant.parse("2026-01-10T10:00:00Z");
    private static final Instant READ_TIME =
            Instant.parse("2026-01-11T10:00:00Z");
    private static final String CLEAN_DATABASE_SQL = """
        TRUNCATE TABLE users
        RESTART IDENTITY CASCADE
        """;

    @BeforeEach
    void cleanDatabase() {
        jdbcClient.sql(CLEAN_DATABASE_SQL).update();
    }

    @Test
    void shouldListRecipientNotificationsNewestFirstWithProjection() {
        arrangeUsersStoryMemory();
        repository.save(notification(
                FIRST_NOTIFICATION_ID,
                RECIPIENT_ID,
                NotificationType.PARTICIPANT_JOINED,
                null,
                BASE_TIME
        ));
        repository.save(notification(
                SECOND_NOTIFICATION_ID,
                RECIPIENT_ID,
                NotificationType.MEMORY_CREATED,
                MEMORY_ID,
                BASE_TIME.plusSeconds(1)
        ));
        repository.save(notification(
                THIRD_NOTIFICATION_ID,
                OTHER_RECIPIENT_ID,
                NotificationType.PHOTOS_ADDED,
                MEMORY_ID,
                BASE_TIME.plusSeconds(2)
        ));

        List<NotificationReadModel> notifications =
                repository.findByRecipientUserId(RECIPIENT_ID, 50);

        assertThat(notifications)
                .extracting(NotificationReadModel::id)
                .containsExactly(SECOND_NOTIFICATION_ID, FIRST_NOTIFICATION_ID);

        NotificationReadModel newest = notifications.get(0);
        assertThat(newest.type())
                .isEqualTo(NotificationType.MEMORY_CREATED);
        assertThat(newest.actor().userId()).isEqualTo(ACTOR_ID);
        assertThat(newest.actor().displayName()).isEqualTo("Actor User");
        assertThat(newest.actor().avatarUrl())
                .isEqualTo("/api/v1/stories/%s/participants/%s/avatar/%d"
                        .formatted(
                                STORY_ID,
                                ACTOR_ID,
                                BASE_TIME.toEpochMilli()
                        ));
        assertThat(newest.story().storyId()).isEqualTo(STORY_ID);
        assertThat(newest.story().title()).isEqualTo("Our Story");
        assertThat(newest.memory().memoryId()).isEqualTo(MEMORY_ID);
        assertThat(newest.memory().title()).isEqualTo("First Memory");
        assertThat(newest.read()).isFalse();
    }

    @Test
    void shouldOrderSameTimestampByIdDescending() {
        arrangeUsersStoryMemory();
        repository.save(notification(
                FIRST_NOTIFICATION_ID,
                RECIPIENT_ID,
                NotificationType.MEMORY_CREATED,
                MEMORY_ID,
                BASE_TIME
        ));
        repository.save(notification(
                SECOND_NOTIFICATION_ID,
                RECIPIENT_ID,
                NotificationType.PHOTOS_ADDED,
                MEMORY_ID,
                BASE_TIME
        ));

        List<NotificationReadModel> notifications =
                repository.findByRecipientUserId(RECIPIENT_ID, 50);

        assertThat(notifications)
                .extracting(NotificationReadModel::id)
                .containsExactly(SECOND_NOTIFICATION_ID, FIRST_NOTIFICATION_ID);
    }

    @Test
    void shouldApplyLimit() {
        arrangeUsersStoryMemory();
        repository.save(notification(
                FIRST_NOTIFICATION_ID,
                RECIPIENT_ID,
                NotificationType.PARTICIPANT_JOINED,
                null,
                BASE_TIME
        ));
        repository.save(notification(
                SECOND_NOTIFICATION_ID,
                RECIPIENT_ID,
                NotificationType.MEMORY_CREATED,
                MEMORY_ID,
                BASE_TIME.plusSeconds(1)
        ));

        List<NotificationReadModel> notifications =
                repository.findByRecipientUserId(RECIPIENT_ID, 1);

        assertThat(notifications)
                .extracting(NotificationReadModel::id)
                .containsExactly(SECOND_NOTIFICATION_ID);
    }

    @Test
    void shouldCountUnreadAndMarkOneReadIdempotentlyForRecipientOnly() {
        arrangeUsersStoryMemory();
        repository.save(notification(
                FIRST_NOTIFICATION_ID,
                RECIPIENT_ID,
                NotificationType.PARTICIPANT_JOINED,
                null,
                BASE_TIME
        ));
        repository.save(notification(
                SECOND_NOTIFICATION_ID,
                OTHER_RECIPIENT_ID,
                NotificationType.MEMORY_CREATED,
                MEMORY_ID,
                BASE_TIME
        ));

        boolean otherRecipientMarked = repository.markRead(
                RECIPIENT_ID,
                SECOND_NOTIFICATION_ID,
                READ_TIME
        );
        boolean marked = repository.markRead(
                RECIPIENT_ID,
                FIRST_NOTIFICATION_ID,
                READ_TIME
        );
        boolean markedAgain = repository.markRead(
                RECIPIENT_ID,
                FIRST_NOTIFICATION_ID,
                READ_TIME.plusSeconds(60)
        );

        assertThat(otherRecipientMarked).isFalse();
        assertThat(marked).isTrue();
        assertThat(markedAgain).isTrue();
        assertThat(repository.countUnreadByRecipientUserId(RECIPIENT_ID))
                .isZero();
        assertThat(repository.countUnreadByRecipientUserId(OTHER_RECIPIENT_ID))
                .isEqualTo(1);

        NotificationReadModel notification =
                repository.findByRecipientUserId(RECIPIENT_ID, 50).get(0);
        assertThat(notification.readAt()).isEqualTo(READ_TIME);
    }

    @Test
    void shouldMarkAllUnreadForRecipientOnly() {
        arrangeUsersStoryMemory();
        repository.save(notification(
                FIRST_NOTIFICATION_ID,
                RECIPIENT_ID,
                NotificationType.PARTICIPANT_JOINED,
                null,
                BASE_TIME
        ));
        repository.save(notification(
                SECOND_NOTIFICATION_ID,
                RECIPIENT_ID,
                NotificationType.MEMORY_CREATED,
                MEMORY_ID,
                BASE_TIME
        ));
        repository.save(notification(
                THIRD_NOTIFICATION_ID,
                OTHER_RECIPIENT_ID,
                NotificationType.PHOTOS_ADDED,
                MEMORY_ID,
                BASE_TIME
        ));

        repository.markAllRead(RECIPIENT_ID, READ_TIME);

        assertThat(repository.countUnreadByRecipientUserId(RECIPIENT_ID))
                .isZero();
        assertThat(repository.countUnreadByRecipientUserId(OTHER_RECIPIENT_ID))
                .isEqualTo(1);
    }

    @Test
    void shouldTolerateDeletedMemoryAndStoryReferences() {
        arrangeUsersStoryMemory();
        repository.save(notification(
                FIRST_NOTIFICATION_ID,
                RECIPIENT_ID,
                NotificationType.MEMORY_CREATED,
                MEMORY_ID,
                BASE_TIME
        ));

        memoryRepository.delete(MEMORY_ID);
        jdbcClient.sql("""
                DELETE FROM stories
                WHERE id = :storyId
                """)
                .param("storyId", STORY_ID)
                .update();

        NotificationReadModel notification =
                repository.findByRecipientUserId(RECIPIENT_ID, 50).get(0);

        assertThat(notification.story().storyId()).isNull();
        assertThat(notification.story().title()).isNull();
        assertThat(notification.memory()).isNull();
    }

    @Test
    void shouldNotExposeEmailOrRawStorageKeysInProjection() {
        arrangeUsersStoryMemory();
        repository.save(notification(
                FIRST_NOTIFICATION_ID,
                RECIPIENT_ID,
                NotificationType.MEMORY_CREATED,
                MEMORY_ID,
                BASE_TIME
        ));

        NotificationReadModel notification =
                repository.findByRecipientUserId(RECIPIENT_ID, 50).get(0);

        assertThat(notification.actor().avatarUrl())
                .doesNotContain("custom-avatar-storage-key")
                .doesNotContain("email")
                .doesNotContain("minio");
    }

    private void arrangeUsersStoryMemory() {
        userRepository.save(user(RECIPIENT_ID, "recipient-google", null));
        userRepository.save(user(OTHER_RECIPIENT_ID, "other-google", null));
        userRepository.save(user(
                ACTOR_ID,
                "actor-google",
                "custom-avatar-storage-key"
        ));
        storyRepository.save(new Story(
                STORY_ID,
                RECIPIENT_ID,
                "Our Story",
                "The beginning",
                null,
                BASE_TIME,
                BASE_TIME
        ));
        storyParticipantRepository.save(new StoryParticipant(
                STORY_ID,
                RECIPIENT_ID,
                StoryRole.OWNER,
                BASE_TIME
        ));
        storyParticipantRepository.save(new StoryParticipant(
                STORY_ID,
                ACTOR_ID,
                StoryRole.CO_OWNER,
                BASE_TIME
        ));
        memoryRepository.save(new Memory(
                MEMORY_ID,
                STORY_ID,
                ACTOR_ID,
                "First Memory",
                "A memory",
                "Tbilisi",
                41.715137,
                44.827096,
                LocalDate.of(2025, 5, 1),
                BASE_TIME,
                BASE_TIME
        ));
    }

    private static User user(
            UUID id,
            String googleSubject,
            String customAvatarStorageKey
    ) {
        return new User(
                id,
                googleSubject,
                id.equals(ACTOR_ID) ? "Actor User" : "Recipient User",
                "https://accounts.example/avatar/" + id,
                customAvatarStorageKey,
                customAvatarStorageKey == null ? null : BASE_TIME,
                BASE_TIME,
                BASE_TIME,
                null
        );
    }

    private static Notification notification(
            UUID id,
            UUID recipientUserId,
            NotificationType type,
            UUID memoryId,
            Instant createdAt
    ) {
        return new Notification(
                id,
                recipientUserId,
                type,
                ACTOR_ID,
                STORY_ID,
                memoryId,
                createdAt,
                null
        );
    }
}
