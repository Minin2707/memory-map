package memory_map.backend.story.repository;

import memory_map.backend.IntegrationTest;
import memory_map.backend.story.domain.Story;
import memory_map.backend.user.domain.User;
import memory_map.backend.user.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.simple.JdbcClient;

import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

class StoryRepositoryTest extends IntegrationTest {

    @Autowired
    private StoryRepository repository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private JdbcClient jdbcClient;

    @Autowired
    private Clock clock;

    private int storyTimestampOffsetSeconds;

    private static final String CLEAN_DATABASE_SQL = """
        TRUNCATE TABLE users
        RESTART IDENTITY CASCADE
        """;

    @BeforeEach
    void cleanDatabase() {
        storyTimestampOffsetSeconds = 0;
        jdbcClient.sql(CLEAN_DATABASE_SQL).update();
    }

    private User createUser(String googleSubject) {
        Instant now = Instant.now(clock);

        return new User(
                UUID.randomUUID(),
                googleSubject,
                "Konstantin",
                null,
                now,
                now
        );
    }

    private Story createStory(UUID ownerId) {
        Instant now = Instant.now(clock)
                .plusSeconds(storyTimestampOffsetSeconds++);

        return new Story(
                UUID.randomUUID(),
                ownerId,
                "Our Story",
                "The beginning of our journey",
                now,
                now
        );
    }

    @Test
    void shouldSaveStory() {

        User user = userRepository.save(
                createUser("google-subject-123")
        );

        Story story = createStory(user.id());

        Story saved = repository.save(story);

        Story loaded = repository.findById(saved.id())
                .orElseThrow();

        assertThat(loaded).isEqualTo(saved);
    }

    @Test
    void shouldFindStoryById() {

        User user = userRepository.save(
                createUser("google-subject-123")
        );

        Story saved = repository.save(
                createStory(user.id())
        );

        Optional<Story> found =
                repository.findById(saved.id());

        assertThat(found).isPresent();

        assertThat(found.get())
                .isEqualTo(saved);
    }

    @Test
    void shouldReturnEmptyWhenStoryDoesNotExist() {

        UUID id = UUID.randomUUID();

        Optional<Story> found =
                repository.findById(id);

        assertThat(found).isEmpty();
    }

    @Test
    void shouldFindStoriesByOwnerId() {

        User user = userRepository.save(
                createUser("google-subject-123")
        );

        Story first = repository.save(
                createStory(user.id())
        );

        Story second = repository.save(
                createStory(user.id())
        );

        Story third = repository.save(
                createStory(user.id())
        );

        List<Story> stories =
                repository.findByOwnerId(user.id());

        assertThat(stories)
                .hasSize(3)
                .containsExactly(third, second, first);
    }
}
