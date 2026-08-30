package memory_map.backend.story.repository;

import memory_map.backend.IntegrationTest;
import memory_map.backend.common.database.DatabaseTimestamps;
import memory_map.backend.music.domain.MusicTrackStatus;
import memory_map.backend.story.domain.Story;
import memory_map.backend.story.domain.StoryCoverMetadata;
import memory_map.backend.user.domain.User;
import memory_map.backend.user.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class StoryRepositoryTest extends IntegrationTest {

    @Autowired
    private StoryRepository repository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private JdbcClient jdbcClient;

    @Autowired
    private Clock clock;

    @Autowired
    private PlatformTransactionManager transactionManager;

    private int storyTimestampOffsetSeconds;

    private static final String CLEAN_DATABASE_SQL = """
        TRUNCATE TABLE users, music_tracks
        RESTART IDENTITY CASCADE
        """;

    private static final Instant COVER_UPDATED_AT =
            Instant.parse("2026-01-01T10:00:00Z");

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
                null,
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
        assertThat(loaded.cover()).isNull();
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
    void shouldFindStoryForUpdateWithCoverMetadata() {

        User user = userRepository.save(
                createUser("google-subject-123")
        );
        Story saved = repository.save(createStory(user.id()));
        StoryCoverMetadata cover = coverMetadata("object-1", COVER_UPDATED_AT);
        Story withCover = repository.updateCover(saved.id(), cover);

        Optional<Story> found = repository.findByIdForUpdate(saved.id());

        assertThat(found).contains(withCover);
        assertThat(found.orElseThrow().cover()).isEqualTo(cover);
    }

    @Test
    void shouldLockExistingStoryById() {

        User user = userRepository.save(
                createUser("google-subject-123")
        );
        Story saved = repository.save(createStory(user.id()));

        boolean locked = repository.lockById(saved.id());

        assertThat(locked).isTrue();
        assertThat(repository.findById(saved.id())).contains(saved);
    }

    @Test
    void shouldReturnFalseWhenLockingMissingStory() {

        boolean locked = repository.lockById(UUID.randomUUID());

        assertThat(locked).isFalse();
    }

    @Test
    void shouldRejectNullStoryLockId() {

        assertThatThrownBy(() -> repository.lockById(null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("id must not be null");
    }

    @Test
    void shouldRejectNullStoryFindForUpdateId() {

        assertThatThrownBy(() -> repository.findByIdForUpdate(null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("id must not be null");
    }

    @Test
    void shouldHoldStoryLockUntilTransactionCompletes() throws Exception {

        User user = userRepository.save(
                createUser("google-subject-123")
        );
        Story saved = repository.save(createStory(user.id()));
        TransactionTemplate transactionTemplate =
                new TransactionTemplate(transactionManager);
        ExecutorService executor = Executors.newFixedThreadPool(2);
        CountDownLatch firstLockAcquired = new CountDownLatch(1);
        CountDownLatch releaseFirstTransaction = new CountDownLatch(1);
        CountDownLatch secondLockAttemptStarted = new CountDownLatch(1);

        try {
            Future<Boolean> first = executor.submit(() ->
                    transactionTemplate.execute(status -> {
                        boolean locked = repository.lockById(saved.id());
                        firstLockAcquired.countDown();
                        await(releaseFirstTransaction);
                        status.setRollbackOnly();

                        return locked;
                    })
            );

            assertThat(firstLockAcquired.await(10, TimeUnit.SECONDS))
                    .isTrue();

            Future<Boolean> second = executor.submit(() ->
                    transactionTemplate.execute(status -> {
                        secondLockAttemptStarted.countDown();

                        return repository.lockById(saved.id());
                    })
            );

            assertThat(secondLockAttemptStarted.await(10, TimeUnit.SECONDS))
                    .isTrue();
            assertThatThrownBy(() -> second.get(250, TimeUnit.MILLISECONDS))
                    .isInstanceOf(TimeoutException.class);

            releaseFirstTransaction.countDown();

            assertThat(first.get(10, TimeUnit.SECONDS)).isTrue();
            assertThat(second.get(10, TimeUnit.SECONDS)).isTrue();
            assertThat(repository.findById(saved.id())).contains(saved);
        } finally {
            releaseFirstTransaction.countDown();
            executor.shutdownNow();
        }
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

    @Test
    void shouldUpdateStory() {

        User user = userRepository.save(
                createUser("google-subject-123")
        );
        Story saved = repository.save(createStory(user.id()));
        Instant updatedAt = saved.updatedAt().plusSeconds(60);

        Story updated = repository.update(new Story(
                saved.id(),
                saved.ownerId(),
                "Updated Story",
                "Updated description",
                saved.soundtrackId(),
                saved.createdAt(),
                updatedAt
        ));

        assertThat(updated.id()).isEqualTo(saved.id());
        assertThat(updated.ownerId()).isEqualTo(saved.ownerId());
        assertThat(updated.title()).isEqualTo("Updated Story");
        assertThat(updated.description())
                .isEqualTo("Updated description");
        assertThat(updated.createdAt()).isEqualTo(saved.createdAt());
        assertThat(updated.updatedAt()).isEqualTo(updatedAt);
        assertThat(repository.findById(saved.id()))
                .contains(updated);
    }

    @Test
    void shouldUpdateCoverMetadata() {

        User user = userRepository.save(
                createUser("google-subject-123")
        );
        Story saved = repository.save(createStory(user.id()));
        StoryCoverMetadata cover = coverMetadata("object-1", COVER_UPDATED_AT);

        Story updated = repository.updateCover(saved.id(), cover);

        assertThat(updated.cover()).isEqualTo(cover);
        assertThat(updated.updatedAt()).isEqualTo(saved.updatedAt());
        assertThat(repository.findById(saved.id()).orElseThrow().cover())
                .isEqualTo(cover);
    }

    @Test
    void shouldReplaceCoverMetadata() {

        User user = userRepository.save(
                createUser("google-subject-123")
        );
        Story saved = repository.save(createStory(user.id()));
        StoryCoverMetadata first = coverMetadata("object-1", COVER_UPDATED_AT);
        StoryCoverMetadata second = coverMetadata(
                "object-2",
                COVER_UPDATED_AT.plusSeconds(60)
        );
        repository.updateCover(saved.id(), first);

        Story updated = repository.updateCover(saved.id(), second);

        assertThat(updated.cover()).isEqualTo(second);
        assertThat(repository.findById(saved.id()).orElseThrow().cover())
                .isEqualTo(second);
    }

    @Test
    void shouldClearCoverMetadata() {

        User user = userRepository.save(
                createUser("google-subject-123")
        );
        Story saved = repository.save(createStory(user.id()));
        repository.updateCover(
                saved.id(),
                coverMetadata("object-1", COVER_UPDATED_AT)
        );

        Story updated = repository.clearCover(saved.id());

        assertThat(updated.cover()).isNull();
        assertThat(repository.findById(saved.id()).orElseThrow().cover())
                .isNull();
        assertThat(countCoverMetadataColumns(saved.id())).isZero();
    }

    @Test
    void shouldPreserveCoverMetadataWhenUpdatingStory() {

        User user = userRepository.save(
                createUser("google-subject-123")
        );
        Story saved = repository.save(createStory(user.id()));
        StoryCoverMetadata cover = coverMetadata("object-1", COVER_UPDATED_AT);
        Story withCover = repository.updateCover(saved.id(), cover);
        Instant metadataUpdatedAt = withCover.updatedAt().plusSeconds(60);

        Story updated = repository.update(new Story(
                withCover.id(),
                withCover.ownerId(),
                "Updated Story",
                "Updated description",
                withCover.soundtrackId(),
                withCover.createdAt(),
                metadataUpdatedAt
        ));

        assertThat(updated.cover()).isEqualTo(cover);
        assertThat(updated.updatedAt()).isEqualTo(metadataUpdatedAt);
        assertThat(repository.findById(saved.id()).orElseThrow().cover())
                .isEqualTo(cover);
    }

    @Test
    void shouldUpdateStoryDescriptionToNull() {

        User user = userRepository.save(
                createUser("google-subject-123")
        );
        Story saved = repository.save(createStory(user.id()));

        Story updated = repository.update(new Story(
                saved.id(),
                saved.ownerId(),
                saved.title(),
                null,
                saved.soundtrackId(),
                saved.createdAt(),
                saved.updatedAt().plusSeconds(60)
        ));

        assertThat(updated.description()).isNull();
        assertThat(repository.findById(saved.id())
                .orElseThrow()
                .description())
                .isNull();
    }

    @Test
    void shouldPreserveStoredOwnerIdAndCreatedAtWhenUpdatingStory() {

        User originalOwner = userRepository.save(
                createUser("google-subject-123")
        );
        User otherUser = userRepository.save(
                createUser("google-subject-456")
        );
        Story saved = repository.save(createStory(originalOwner.id()));

        Story updated = repository.update(new Story(
                saved.id(),
                otherUser.id(),
                "Updated Story",
                "Updated description",
                saved.soundtrackId(),
                saved.createdAt().plusSeconds(120),
                saved.updatedAt().plusSeconds(60)
        ));

        assertThat(updated.ownerId()).isEqualTo(originalOwner.id());
        assertThat(updated.createdAt()).isEqualTo(saved.createdAt());
        assertThat(repository.findById(saved.id()))
                .contains(updated);
    }

    @Test
    void shouldSaveAndFindStoryWithSoundtrackId() {

        User user = userRepository.save(
                createUser("google-subject-123")
        );
        UUID soundtrackId = UUID.randomUUID();
        insertMusicTrack(soundtrackId);
        Instant now = Instant.now(clock);
        Story story = new Story(
                UUID.randomUUID(),
                user.id(),
                "Our Story",
                "The beginning of our journey",
                soundtrackId,
                now,
                now
        );

        Story saved = repository.save(story);

        assertThat(saved.soundtrackId()).isEqualTo(soundtrackId);
        assertThat(repository.findById(saved.id()))
                .contains(saved);
    }

    @Test
    void shouldPreserveSoundtrackIdWhenUpdatingStory() {

        User user = userRepository.save(
                createUser("google-subject-123")
        );
        UUID soundtrackId = UUID.randomUUID();
        insertMusicTrack(soundtrackId);
        Instant now = Instant.now(clock);
        Story saved = repository.save(new Story(
                UUID.randomUUID(),
                user.id(),
                "Our Story",
                "The beginning of our journey",
                soundtrackId,
                now,
                now
        ));

        Story updated = repository.update(new Story(
                saved.id(),
                saved.ownerId(),
                "Updated Story",
                "Updated description",
                saved.soundtrackId(),
                saved.createdAt(),
                saved.updatedAt().plusSeconds(60)
        ));

        assertThat(updated.soundtrackId()).isEqualTo(soundtrackId);
        assertThat(repository.findById(saved.id()))
                .contains(updated);
    }

    @Test
    void shouldPreserveCoverMetadataWhenUpdatingStoryWithSoundtrack() {

        User user = userRepository.save(
                createUser("google-subject-123")
        );
        UUID soundtrackId = UUID.randomUUID();
        insertMusicTrack(soundtrackId);
        Story saved = repository.save(createStory(user.id()));
        StoryCoverMetadata cover = coverMetadata("object-1", COVER_UPDATED_AT);
        Story withCover = repository.updateCover(saved.id(), cover);

        Story updated = repository.update(new Story(
                withCover.id(),
                withCover.ownerId(),
                withCover.title(),
                withCover.description(),
                soundtrackId,
                withCover.createdAt(),
                withCover.updatedAt().plusSeconds(60)
        ));

        assertThat(updated.soundtrackId()).isEqualTo(soundtrackId);
        assertThat(updated.cover()).isEqualTo(cover);
        assertThat(repository.findById(saved.id()).orElseThrow().cover())
                .isEqualTo(cover);
    }

    @Test
    void shouldRejectStoryWithUnknownSoundtrackId() {

        User user = userRepository.save(
                createUser("google-subject-123")
        );
        Instant now = Instant.now(clock);
        Story story = new Story(
                UUID.randomUUID(),
                user.id(),
                "Our Story",
                "The beginning of our journey",
                UUID.randomUUID(),
                now,
                now
        );

        assertThatThrownBy(() -> repository.save(story))
                .isInstanceOf(DataIntegrityViolationException.class);
    }

    private void insertMusicTrack(UUID id) {
        Instant now = Instant.now(clock);

        jdbcClient.sql("""
                INSERT INTO music_tracks (
                    id,
                    title,
                    artist,
                    duration_seconds,
                    status,
                    sort_order,
                    storage_key,
                    mime_type,
                    file_size,
                    created_at,
                    updated_at
                )
                VALUES (
                    :id,
                    :title,
                    :artist,
                    :durationSeconds,
                    :status,
                    :sortOrder,
                    :storageKey,
                    :mimeType,
                    :fileSize,
                    :createdAt,
                    :updatedAt
                )
                """)
                .param("id", id)
                .param("title", "Calm Piano")
                .param("artist", "Memory Story")
                .param("durationSeconds", 180)
                .param("status", MusicTrackStatus.ACTIVE.name())
                .param("sortOrder", 0)
                .param("storageKey", "music/" + id + ".mp3")
                .param("mimeType", "audio/mpeg")
                .param("fileSize", 4_096L)
                .param("createdAt", DatabaseTimestamps.toOffsetDateTime(now))
                .param("updatedAt", DatabaseTimestamps.toOffsetDateTime(now))
                .update();
    }

    private static StoryCoverMetadata coverMetadata(
            String objectId,
            Instant updatedAt
    ) {
        return new StoryCoverMetadata(
                "stories/story-1/cover/%s/display".formatted(objectId),
                2_048L,
                "stories/story-1/cover/%s/thumbnail".formatted(objectId),
                512L,
                "image/jpeg",
                updatedAt
        );
    }

    private int countCoverMetadataColumns(UUID storyId) {
        return jdbcClient.sql("""
                SELECT
                    (
                        CASE WHEN cover_display_storage_key IS NULL
                            THEN 0 ELSE 1 END
                        + CASE WHEN cover_display_file_size IS NULL
                            THEN 0 ELSE 1 END
                        + CASE WHEN cover_thumbnail_storage_key IS NULL
                            THEN 0 ELSE 1 END
                        + CASE WHEN cover_thumbnail_file_size IS NULL
                            THEN 0 ELSE 1 END
                        + CASE WHEN cover_mime_type IS NULL
                            THEN 0 ELSE 1 END
                        + CASE WHEN cover_updated_at IS NULL
                            THEN 0 ELSE 1 END
                    ) AS metadata_count
                FROM stories
                WHERE id = :storyId
                """)
                .param("storyId", storyId)
                .query(Integer.class)
                .single();
    }

    private static void await(CountDownLatch latch) {
        try {
            if (!latch.await(10, TimeUnit.SECONDS)) {
                throw new IllegalStateException("Timed out waiting");
            }
        } catch (InterruptedException exception) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException(
                    "Interrupted while waiting",
                    exception
            );
        }
    }
}
