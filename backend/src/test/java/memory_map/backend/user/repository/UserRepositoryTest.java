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

    private static final Instant DELETED_AT =
            Instant.parse("2026-01-15T10:00:00.123456Z");

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

    @Test
    void shouldTombstoneUserAndRemovePersonalIdentity() {

        User saved = repository.save(
                createUser(
                        "google-subject-123",
                        "Konstantin",
                        "https://example.com/avatar.png"
                )
        );

        boolean tombstoned = repository.tombstoneById(
                saved.id(),
                DELETED_AT
        );

        User loaded = repository.findById(saved.id()).orElseThrow();

        assertThat(tombstoned).isTrue();
        assertThat(loaded.id()).isEqualTo(saved.id());
        assertThat(loaded.googleSubject()).isNull();
        assertThat(loaded.displayName()).isEqualTo("Deleted user");
        assertThat(loaded.displayNameCustomized()).isFalse();
        assertThat(loaded.avatarUrl()).isNull();
        assertThat(loaded.customAvatarStorageKey()).isNull();
        assertThat(loaded.customAvatarUpdatedAt()).isNull();
        assertThat(loaded.updatedAt()).isEqualTo(DELETED_AT);
        assertThat(loaded.deletedAt()).isEqualTo(DELETED_AT);
        assertThat(loaded.isDeleted()).isTrue();
    }

    @Test
    void shouldNotFindTombstonedUserByGoogleSubject() {

        User saved = repository.save(
                createUser("google-subject-123")
        );

        repository.tombstoneById(saved.id(), Instant.now(clock));

        assertThat(repository.findByGoogleSubject("google-subject-123"))
                .isEmpty();
        assertThat(repository.existsActiveById(saved.id())).isFalse();
        assertThat(repository.findActiveByIdForUpdate(saved.id())).isEmpty();
    }

    @Test
    void shouldAllowNewUserWithSameGoogleSubjectAfterTombstone() {

        User deleted = repository.save(
                createUser("google-subject-123")
        );
        repository.tombstoneById(deleted.id(), Instant.now(clock));

        User recreated = repository.save(
                createUser(
                        "google-subject-123",
                        "New User",
                        null
                )
        );

        assertThat(recreated.id()).isNotEqualTo(deleted.id());
        assertThat(repository.findByGoogleSubject("google-subject-123"))
                .contains(recreated);
    }

    @Test
    void shouldUpdateDisplayNameAndMarkCustomized() {

        User saved = repository.save(
                createUser(
                        "google-subject-123",
                        "Konstantin",
                        "https://example.com/google.png"
                )
        );
        repository.updateCustomAvatar(
                saved.id(),
                "users/%s/avatar/avatar-object".formatted(saved.id()),
                DELETED_AT
        );

        User updated = repository.updateDisplayName(
                saved.id(),
                "Анна-Мария O'Connor",
                DELETED_AT.plusSeconds(1)
        );

        assertThat(updated.displayName()).isEqualTo("Анна-Мария O'Connor");
        assertThat(updated.displayNameCustomized()).isTrue();
        assertThat(updated.avatarUrl())
                .isEqualTo("https://example.com/google.png");
        assertThat(updated.customAvatarStorageKey())
                .isEqualTo("users/%s/avatar/avatar-object".formatted(
                        saved.id()
                ));
        assertThat(updated.updatedAt()).isEqualTo(DELETED_AT.plusSeconds(1));
    }

    @Test
    void shouldUpdateGoogleProfileFallbackOnlyWhenDisplayNameIsNotCustomized() {

        User saved = repository.save(
                createUser(
                        "google-subject-123",
                        "George",
                        "https://example.com/old-google.png"
                )
        );

        User updated = repository.updateGoogleProfileFallback(
                saved.id(),
                "Georgy",
                "https://example.com/new-google.png",
                DELETED_AT
        );

        assertThat(updated.displayName()).isEqualTo("Georgy");
        assertThat(updated.displayNameCustomized()).isFalse();
        assertThat(updated.avatarUrl())
                .isEqualTo("https://example.com/new-google.png");

        User customized = repository.updateDisplayName(
                saved.id(),
                "Georgy B.",
                DELETED_AT.plusSeconds(1)
        );

        assertThatThrownBy(() -> repository.updateGoogleProfileFallback(
                customized.id(),
                "George Belyavsky",
                "https://example.com/another-google.png",
                DELETED_AT.plusSeconds(2)
        ))
                .isInstanceOf(org.springframework.dao
                        .IncorrectResultSizeDataAccessException.class);

        User loaded = repository.findById(saved.id()).orElseThrow();
        assertThat(loaded.displayName()).isEqualTo("Georgy B.");
        assertThat(loaded.displayNameCustomized()).isTrue();
        assertThat(loaded.avatarUrl())
                .isEqualTo("https://example.com/new-google.png");
    }

    @Test
    void shouldUpdateAndClearCustomAvatarMetadata() {

        User saved = repository.save(
                createUser(
                        "google-subject-123",
                        "Konstantin",
                        "https://example.com/google.png"
                )
        );

        User withCustomAvatar = repository.updateCustomAvatar(
                saved.id(),
                "users/%s/avatar/avatar-object".formatted(saved.id()),
                DELETED_AT
        );

        assertThat(withCustomAvatar.avatarUrl())
                .isEqualTo("https://example.com/google.png");
        assertThat(withCustomAvatar.customAvatarStorageKey())
                .isEqualTo("users/%s/avatar/avatar-object".formatted(
                        saved.id()
                ));
        assertThat(withCustomAvatar.customAvatarUpdatedAt())
                .isEqualTo(DELETED_AT);
        assertThat(withCustomAvatar.hasCustomAvatar()).isTrue();

        User cleared = repository.clearCustomAvatar(
                saved.id(),
                DELETED_AT.plusSeconds(1)
        );

        assertThat(cleared.avatarUrl())
                .isEqualTo("https://example.com/google.png");
        assertThat(cleared.customAvatarStorageKey()).isNull();
        assertThat(cleared.customAvatarUpdatedAt()).isNull();
        assertThat(cleared.hasCustomAvatar()).isFalse();
    }

    @Test
    void shouldUpdateGoogleAvatarWithoutRemovingCustomAvatar() {

        User saved = repository.save(
                createUser(
                        "google-subject-123",
                        "Konstantin",
                        "https://example.com/old-google.png"
                )
        );
        repository.updateCustomAvatar(
                saved.id(),
                "users/%s/avatar/avatar-object".formatted(saved.id()),
                DELETED_AT
        );

        User updated = repository.updateGoogleAvatarUrl(
                saved.id(),
                "https://example.com/new-google.png",
                DELETED_AT.plusSeconds(1)
        );

        assertThat(updated.avatarUrl())
                .isEqualTo("https://example.com/new-google.png");
        assertThat(updated.customAvatarStorageKey())
                .isEqualTo("users/%s/avatar/avatar-object".formatted(
                        saved.id()
                ));
        assertThat(updated.hasCustomAvatar()).isTrue();
    }
}
