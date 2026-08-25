package memory_map.backend.media.repository;

import memory_map.backend.IntegrationTest;
import memory_map.backend.media.domain.MediaFile;
import memory_map.backend.media.domain.MediaType;
import memory_map.backend.memory.domain.Memory;
import memory_map.backend.memory.repository.MemoryRepository;
import memory_map.backend.story.domain.Story;
import memory_map.backend.story.repository.StoryRepository;
import memory_map.backend.user.domain.User;
import memory_map.backend.user.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.jdbc.core.simple.JdbcClient;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class JdbcMediaFileRepositoryTest extends IntegrationTest {

    @Autowired
    private MediaFileRepository repository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private StoryRepository storyRepository;

    @Autowired
    private MemoryRepository memoryRepository;

    @Autowired
    private JdbcClient jdbcClient;

    private static final Instant BASE_TIME =
            Instant.parse("2026-01-01T10:00:00.123456Z");

    private static final String CLEAN_DATABASE_SQL = """
        TRUNCATE TABLE users
        RESTART IDENTITY CASCADE
        """;

    @BeforeEach
    void cleanDatabase() {
        jdbcClient.sql(CLEAN_DATABASE_SQL).update();
    }

    private User createUser(String googleSubject) {
        return new User(
                UUID.randomUUID(),
                googleSubject,
                "Konstantin",
                null,
                BASE_TIME,
                BASE_TIME
        );
    }

    private User saveUser(String googleSubject) {
        return userRepository.save(
                createUser(googleSubject)
        );
    }

    private Story createStory(UUID ownerId) {
        return new Story(
                UUID.randomUUID(),
                ownerId,
                "Our Story",
                "The beginning of our journey",
                null,
                BASE_TIME,
                BASE_TIME
        );
    }

    private Story saveStory(User owner) {
        return storyRepository.save(
                createStory(owner.id())
        );
    }

    private Memory createMemory(
            UUID storyId,
            UUID createdBy
    ) {
        return new Memory(
                UUID.randomUUID(),
                storyId,
                createdBy,
                "First trip",
                "A spring walk",
                "Tbilisi",
                41.715137,
                44.827096,
                LocalDate.of(2024, 5, 20),
                BASE_TIME,
                BASE_TIME
        );
    }

    private Memory saveMemory(
            Story story,
            User createdBy
    ) {
        Memory memory = createMemory(
                story.id(),
                createdBy.id()
        );

        memoryRepository.save(memory);

        return memory;
    }

    private Memory saveMemory(String googleSubject) {
        User user = saveUser(googleSubject);
        Story story = saveStory(user);

        return saveMemory(story, user);
    }

    private MediaFile createMediaFile(UUID memoryId) {
        UUID id = UUID.randomUUID();

        return createMediaFile(
                id,
                memoryId,
                MediaType.PHOTO,
                "display-key-" + id,
                1_024L,
                "thumbnail-key-" + id,
                128L,
                "image/jpeg",
                BASE_TIME
        );
    }

    private MediaFile createMediaFile(
            UUID id,
            UUID memoryId,
            MediaType type,
            String displayStorageKey,
            long displayFileSize,
            String thumbnailStorageKey,
            long thumbnailFileSize,
            String mimeType,
            Instant createdAt
    ) {
        return new MediaFile(
                id,
                memoryId,
                type,
                displayStorageKey,
                displayFileSize,
                thumbnailStorageKey,
                thumbnailFileSize,
                mimeType,
                createdAt
        );
    }

    private void assertMediaFileMatches(
            MediaFile actual,
            MediaFile expected
    ) {
        assertThat(actual.id()).isEqualTo(expected.id());
        assertThat(actual.memoryId()).isEqualTo(expected.memoryId());
        assertThat(actual.type()).isEqualTo(expected.type());
        assertThat(actual.displayStorageKey())
                .isEqualTo(expected.displayStorageKey());
        assertThat(actual.displayFileSize())
                .isEqualTo(expected.displayFileSize());
        assertThat(actual.thumbnailStorageKey())
                .isEqualTo(expected.thumbnailStorageKey());
        assertThat(actual.thumbnailFileSize())
                .isEqualTo(expected.thumbnailFileSize());
        assertThat(actual.mimeType()).isEqualTo(expected.mimeType());
        assertThat(actual.createdAt()).isEqualTo(expected.createdAt());
    }

    @Test
    void shouldSaveAndFindMediaFileById() {

        Memory memory = saveMemory("google-subject-123");
        MediaFile mediaFile = createMediaFile(memory.id());

        repository.save(mediaFile);

        MediaFile loaded = repository.findById(mediaFile.id())
                .orElseThrow();

        assertMediaFileMatches(loaded, mediaFile);
    }

    @Test
    void shouldPreserveDisplayAndThumbnailMetadata() {

        Memory memory = saveMemory("google-subject-123");
        UUID mediaFileId = UUID.randomUUID();
        MediaFile mediaFile = createMediaFile(
                mediaFileId,
                memory.id(),
                MediaType.PHOTO,
                "display-key",
                2_048L,
                "thumbnail-key",
                256L,
                "image/jpeg",
                BASE_TIME
        );

        repository.save(mediaFile);

        MediaFile loaded = repository.findById(mediaFile.id())
                .orElseThrow();

        assertThat(loaded.displayStorageKey()).isEqualTo("display-key");
        assertThat(loaded.displayFileSize()).isEqualTo(2_048L);
        assertThat(loaded.thumbnailStorageKey()).isEqualTo("thumbnail-key");
        assertThat(loaded.thumbnailFileSize()).isEqualTo(256L);
        assertThat(loaded.mimeType()).isEqualTo("image/jpeg");
    }

    @Test
    void shouldRejectNonPositiveDisplayFileSizeBeforePersistence() {

        Memory memory = saveMemory("google-subject-123");
        UUID mediaFileId = UUID.randomUUID();

        assertThatThrownBy(() -> createMediaFile(
                mediaFileId,
                memory.id(),
                MediaType.PHOTO,
                "display-key",
                0L,
                "thumbnail-key",
                256L,
                "image/jpeg",
                BASE_TIME
        ))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("displayFileSize must be positive");
    }

    @Test
    void shouldReturnEmptyWhenMediaFileDoesNotExist() {

        Optional<MediaFile> found =
                repository.findById(UUID.randomUUID());

        assertThat(found).isEmpty();
    }

    @Test
    void shouldFindMediaFilesByMemoryId() {

        Memory firstMemory = saveMemory("first-google-subject");
        Memory secondMemory = saveMemory("second-google-subject");
        MediaFile first = createMediaFile(firstMemory.id());
        MediaFile second = createMediaFile(
                UUID.randomUUID(),
                firstMemory.id(),
                MediaType.PHOTO,
                "display-key-second",
                2_048L,
                "thumbnail-key-second",
                256L,
                "image/jpeg",
                BASE_TIME.plusSeconds(1)
        );
        MediaFile other = createMediaFile(secondMemory.id());

        repository.save(first);
        repository.save(second);
        repository.save(other);

        List<MediaFile> mediaFiles =
                repository.findByMemoryId(firstMemory.id());

        assertThat(mediaFiles)
                .containsExactly(first, second);
    }

    @Test
    void shouldFindMediaFilesByMemoryIdSortedByCreatedAtAndId() {

        Memory memory = saveMemory("google-subject-123");
        MediaFile first = createMediaFile(
                UUID.fromString("00000000-0000-0000-0000-000000000001"),
                memory.id(),
                MediaType.PHOTO,
                "display-key-first",
                1_024L,
                "thumbnail-key-first",
                128L,
                "image/jpeg",
                BASE_TIME.plusSeconds(1)
        );
        MediaFile second = createMediaFile(
                UUID.fromString("00000000-0000-0000-0000-000000000002"),
                memory.id(),
                MediaType.PHOTO,
                "display-key-second",
                2_048L,
                "thumbnail-key-second",
                256L,
                "image/jpeg",
                BASE_TIME.plusSeconds(2)
        );
        MediaFile third = createMediaFile(
                UUID.fromString("00000000-0000-0000-0000-000000000003"),
                memory.id(),
                MediaType.PHOTO,
                "display-key-third",
                3_072L,
                "thumbnail-key-third",
                384L,
                "image/jpeg",
                BASE_TIME.plusSeconds(2)
        );

        repository.save(third);
        repository.save(second);
        repository.save(first);

        List<MediaFile> mediaFiles =
                repository.findByMemoryId(memory.id());

        assertThat(mediaFiles)
                .extracting(MediaFile::id)
                .containsExactly(
                        first.id(),
                        second.id(),
                        third.id()
                );
    }

    @Test
    void shouldDeleteMediaFile() {

        Memory memory = saveMemory("google-subject-123");
        MediaFile first = createMediaFile(memory.id());
        MediaFile second = createMediaFile(
                UUID.randomUUID(),
                memory.id(),
                MediaType.PHOTO,
                "display-key-second",
                2_048L,
                "thumbnail-key-second",
                256L,
                "image/jpeg",
                BASE_TIME.plusSeconds(1)
        );

        repository.save(first);
        repository.save(second);

        repository.delete(first.id());

        assertThat(repository.findById(first.id()))
                .isEmpty();

        assertThat(repository.findById(second.id()))
                .contains(second);
    }

    @Test
    void shouldRejectDuplicateMediaFileId() {

        Memory memory = saveMemory("google-subject-123");
        MediaFile mediaFile = createMediaFile(memory.id());

        repository.save(mediaFile);

        assertThatThrownBy(() -> repository.save(mediaFile))
                .isInstanceOf(DuplicateKeyException.class);
    }

    @Test
    void shouldRejectMediaFileWithUnknownMemory() {

        MediaFile mediaFile = createMediaFile(UUID.randomUUID());

        assertThatThrownBy(() -> repository.save(mediaFile))
                .isInstanceOf(DataIntegrityViolationException.class);
    }

    @Test
    void shouldCascadeDeleteMediaFilesWhenMemoryIsDeleted() {

        Memory memory = saveMemory("google-subject-123");
        MediaFile mediaFile = createMediaFile(memory.id());

        repository.save(mediaFile);

        memoryRepository.delete(memory.id());

        assertThat(repository.findById(mediaFile.id()))
                .isEmpty();

        assertThat(repository.findByMemoryId(memory.id()))
                .isEmpty();
    }

    @Test
    void shouldRoundTripMediaTypes() {

        Memory memory = saveMemory("google-subject-123");
        MediaFile photo = createMediaFile(
                UUID.randomUUID(),
                memory.id(),
                MediaType.PHOTO,
                "display-key-photo",
                1_024L,
                "thumbnail-key-photo",
                128L,
                "image/jpeg",
                BASE_TIME
        );
        MediaFile voice = createMediaFile(
                UUID.randomUUID(),
                memory.id(),
                MediaType.VOICE,
                "display-key-voice",
                2_048L,
                "thumbnail-key-voice",
                256L,
                "audio/mpeg",
                BASE_TIME.plusSeconds(1)
        );
        MediaFile video = createMediaFile(
                UUID.randomUUID(),
                memory.id(),
                MediaType.VIDEO,
                "display-key-video",
                3_072L,
                "thumbnail-key-video",
                384L,
                "video/mp4",
                BASE_TIME.plusSeconds(2)
        );

        repository.save(photo);
        repository.save(voice);
        repository.save(video);

        assertThat(repository.findById(photo.id()))
                .map(MediaFile::type)
                .contains(MediaType.PHOTO);

        assertThat(repository.findById(voice.id()))
                .map(MediaFile::type)
                .contains(MediaType.VOICE);

        assertThat(repository.findById(video.id()))
                .map(MediaFile::type)
                .contains(MediaType.VIDEO);
    }

}
