package memory_map.backend.user.repository;

import memory_map.backend.IntegrationTest;
import memory_map.backend.user.domain.User;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.jdbc.core.simple.JdbcClient;

import java.time.Clock;
import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class UserRepositoryTest extends IntegrationTest {

    @Autowired
    private UserRepository repository;

    @Autowired
    private JdbcClient jdbcClient;

    @Autowired
    private Clock clock;

    private static final String CLEAN_DATABASE_SQL = """
        TRUNCATE TABLE users
        RESTART IDENTITY CASCADE
        """;

    @BeforeEach
    void cleanDatabase() {
        jdbcClient.sql(CLEAN_DATABASE_SQL).update();
    }

    private User createUser(
            String googleSubject,
            String displayName,
            String avatarUrl
    ) {
        Instant now = Instant.now(clock);

        return new User(
                UUID.randomUUID(),
                googleSubject,
                displayName,
                avatarUrl,
                now,
                now
        );
    }

    private User createUser(String googleSubject) {
        return createUser(
                googleSubject,
                "Konstantin",
                null
        );
    }

    @Test
    void shouldSaveUser() {

        User user = createUser("google-subject-123");

        User saved = repository.save(user);

        User loaded = repository.findById(saved.id()).orElseThrow();

        assertThat(loaded)
                .usingRecursiveComparison()
                .isEqualTo(saved);
    }

    @Test
    void shouldFindUserById() {

        User saved = repository.save(
                createUser("google-subject-123")
        );

        Optional<User> found = repository.findById(saved.id());

        assertThat(found).isPresent();

        assertThat(found.get())
                .usingRecursiveComparison()
                .isEqualTo(saved);
    }

    @Test
    void shouldReturnEmptyWhenUserDoesNotExist() {

        UUID id = UUID.randomUUID();

        Optional<User> found = repository.findById(id);

        assertThat(found).isEmpty();
    }

    @Test
    void shouldFindUserByGoogleSubject() {

        User saved = repository.save(
                createUser("google-subject-123")
        );

        Optional<User> found =
                repository.findByGoogleSubject(
                        "google-subject-123"
                );

        assertThat(found).isPresent();

        assertThat(found.get())
                .usingRecursiveComparison()
                .isEqualTo(saved);
    }

    @Test
    void shouldReturnEmptyWhenGoogleSubjectDoesNotExist() {

        String googleSubject = "unknown-subject";

        Optional<User> found =
                repository.findByGoogleSubject(googleSubject);

        assertThat(found).isEmpty();
    }

    @Test
    void shouldNotSaveUserWithDuplicateGoogleSubject() {

        User first = createUser("google-subject-123");

        User second = createUser(
                "google-subject-123",
                "Another User",
                null
        );

        repository.save(first);

        assertThatThrownBy(() -> repository.save(second))
                .isInstanceOf(DuplicateKeyException.class);
    }
}
