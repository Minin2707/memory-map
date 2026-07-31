package memory_map.backend.story.application;

import memory_map.backend.IntegrationTest;
import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.story.domain.Story;
import memory_map.backend.story.repository.StoryRepository;
import memory_map.backend.storyparticipant.domain.StoryParticipant;
import memory_map.backend.storyparticipant.domain.StoryRole;
import memory_map.backend.storyparticipant.repository.JdbcStoryParticipantRepository;
import memory_map.backend.storyparticipant.repository.StoryParticipantRepository;
import memory_map.backend.user.domain.User;
import memory_map.backend.user.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.context.annotation.Primary;
import org.springframework.jdbc.core.simple.JdbcClient;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

@Import(CreateStoryUseCaseIntegrationTest.CreateStoryUseCaseTestConfiguration.class)
class CreateStoryUseCaseIntegrationTest extends IntegrationTest {

    @Autowired
    private CreateStoryUseCase createStoryUseCase;

    @Autowired
    private StoryRepository storyRepository;

    @Autowired
    private StoryParticipantRepository storyParticipantRepository;

    @Autowired
    private FailingStoryParticipantRepository failingStoryParticipantRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private JdbcClient jdbcClient;

    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000002");
    private static final Instant BASE_TIME =
            Instant.parse("2026-01-01T10:00:00.123456Z");
    private static final Instant CURRENT_TIME =
            Instant.parse("2026-01-10T10:00:00.123456Z");
    private static final String CLEAN_DATABASE_SQL = """
        TRUNCATE TABLE users
        RESTART IDENTITY CASCADE
        """;

    @BeforeEach
    void cleanDatabase() {
        failingStoryParticipantRepository.reset();
        jdbcClient.sql(CLEAN_DATABASE_SQL).update();
    }

    @Test
    void shouldCreateStoryAndOwnerParticipantTransactionally() {

        User user = saveUser();

        Story returnedStory = createStoryUseCase.create(command(user.id()));

        Story persistedStory = storyRepository.findById(STORY_ID)
                .orElseThrow();
        StoryParticipant persistedParticipant =
                storyParticipantRepository.find(STORY_ID, user.id())
                        .orElseThrow();

        assertThat(returnedStory).isEqualTo(expectedStory(user.id()));
        assertThat(persistedStory).isEqualTo(returnedStory);
        assertThat(persistedStory.ownerId()).isEqualTo(user.id());
        assertThat(persistedStory.title()).isEqualTo("Our Story");
        assertThat(persistedStory.description())
                .isEqualTo("The beginning of our journey");
        assertThat(persistedStory.createdAt()).isEqualTo(CURRENT_TIME);
        assertThat(persistedStory.updatedAt()).isEqualTo(CURRENT_TIME);

        assertThat(persistedParticipant.storyId()).isEqualTo(STORY_ID);
        assertThat(persistedParticipant.userId()).isEqualTo(user.id());
        assertThat(persistedParticipant.role()).isEqualTo(StoryRole.OWNER);
        assertThat(persistedParticipant.joinedAt())
                .isEqualTo(CURRENT_TIME);
        assertThat(participantCountByStoryId(STORY_ID)).isEqualTo(1);
    }

    @Test
    void shouldRollbackStoryWhenOwnerParticipantSaveFails() {

        User user = saveUser();
        failingStoryParticipantRepository.failOnSave(
                new RuntimeException("participant save failed")
        );

        assertThatThrownBy(() -> createStoryUseCase.create(command(user.id())))
                .isInstanceOf(RuntimeException.class)
                .hasMessage("participant save failed");

        assertThat(storyRepository.findById(STORY_ID)).isEmpty();
        assertThat(storyParticipantRepository.find(STORY_ID, user.id()))
                .isEmpty();
        assertThat(storyCountById(STORY_ID)).isZero();
        assertThat(participantCountByStoryId(STORY_ID)).isZero();
    }

    private User saveUser() {
        return userRepository.save(
                new User(
                        USER_ID,
                        "google-subject-123",
                        "Konstantin",
                        null,
                        BASE_TIME,
                        BASE_TIME
                )
        );
    }

    private static CreateStoryCommand command(UUID userId) {
        return new CreateStoryCommand(
                new AuthenticatedUser(userId),
                STORY_ID,
                "Our Story",
                "The beginning of our journey",
                CURRENT_TIME
        );
    }

    private static Story expectedStory(UUID ownerId) {
        return new Story(
                STORY_ID,
                ownerId,
                "Our Story",
                "The beginning of our journey",
                CURRENT_TIME,
                CURRENT_TIME
        );
    }

    private int storyCountById(UUID storyId) {
        return jdbcClient.sql("""
                SELECT COUNT(*)
                FROM stories
                WHERE id = :storyId
                """)
                .param("storyId", storyId)
                .query(Integer.class)
                .single();
    }

    private int participantCountByStoryId(UUID storyId) {
        return jdbcClient.sql("""
                SELECT COUNT(*)
                FROM story_participants
                WHERE story_id = :storyId
                """)
                .param("storyId", storyId)
                .query(Integer.class)
                .single();
    }

    @TestConfiguration(proxyBeanMethods = false)
    static class CreateStoryUseCaseTestConfiguration {

        @Bean
        @Primary
        FailingStoryParticipantRepository failingStoryParticipantRepository(
                JdbcStoryParticipantRepository delegate
        ) {
            return new FailingStoryParticipantRepository(delegate);
        }
    }

    static final class FailingStoryParticipantRepository
            implements StoryParticipantRepository {

        private final StoryParticipantRepository delegate;
        private RuntimeException failure;

        private FailingStoryParticipantRepository(
                StoryParticipantRepository delegate
        ) {
            this.delegate = delegate;
        }

        @Override
        public Optional<StoryParticipant> find(UUID storyId, UUID userId) {
            return delegate.find(storyId, userId);
        }

        @Override
        public List<StoryParticipant> findByStoryId(UUID storyId) {
            return delegate.findByStoryId(storyId);
        }

        @Override
        public List<StoryParticipant> findByUserId(UUID userId) {
            return delegate.findByUserId(userId);
        }

        @Override
        public boolean exists(UUID storyId, UUID userId) {
            return delegate.exists(storyId, userId);
        }

        @Override
        public void save(StoryParticipant participant) {
            if (failure != null) {
                throw failure;
            }

            delegate.save(participant);
        }

        @Override
        public void update(StoryParticipant participant) {
            delegate.update(participant);
        }

        @Override
        public void delete(UUID storyId, UUID userId) {
            delegate.delete(storyId, userId);
        }

        private void failOnSave(RuntimeException failure) {
            this.failure = failure;
        }

        private void reset() {
            failure = null;
        }
    }
}
