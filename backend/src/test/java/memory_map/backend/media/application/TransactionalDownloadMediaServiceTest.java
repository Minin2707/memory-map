package memory_map.backend.media.application;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.media.domain.MediaFile;
import memory_map.backend.media.domain.MediaType;
import memory_map.backend.media.repository.MediaFileRepository;
import memory_map.backend.media.storage.StorageException;
import memory_map.backend.media.storage.StorageKey;
import memory_map.backend.media.storage.StorageObjectNotFoundException;
import memory_map.backend.media.storage.StorageObjectWrite;
import memory_map.backend.media.storage.StorageService;
import memory_map.backend.media.storage.StoredObject;
import memory_map.backend.memory.domain.Memory;
import memory_map.backend.memory.repository.MemoryRepository;
import memory_map.backend.storyparticipant.domain.StoryParticipant;
import memory_map.backend.storyparticipant.domain.StoryRole;
import memory_map.backend.storyparticipant.repository.StoryParticipantRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;

import java.io.ByteArrayInputStream;
import java.io.InputStream;
import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class TransactionalDownloadMediaServiceTest {

    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID OTHER_USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000002");
    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000011");
    private static final UUID OTHER_STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000012");
    private static final UUID MEMORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000021");
    private static final UUID MEDIA_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000031");
    private static final Instant BASE_TIME =
            Instant.parse("2026-01-10T10:00:00Z");
    private static final byte[] STORED_BYTES = new byte[] {1, 2, 3};

    private final List<String> events = new ArrayList<>();
    private final FakeMediaFileRepository mediaFileRepository =
            new FakeMediaFileRepository(events);
    private final FakeMemoryRepository memoryRepository =
            new FakeMemoryRepository(events);
    private final FakeStoryParticipantRepository storyParticipantRepository =
            new FakeStoryParticipantRepository(events);
    private final FakeStorageService storageService =
            new FakeStorageService(events);
    private final TransactionalDownloadMediaService service =
            new TransactionalDownloadMediaService(
                    mediaFileRepository,
                    memoryRepository,
                    storyParticipantRepository,
                    storageService
            );

    @Test
    void shouldDownloadDisplayUsingTrustedStorageKeyAndDatabaseMetadata()
            throws Exception {

        storageService.storedObject = new StoredObject(
                new ByteArrayInputStream(STORED_BYTES),
                999L,
                "application/octet-stream"
        );

        DownloadedMedia result = service.downloadMedia(
                user(),
                MEDIA_ID,
                MediaRepresentation.DISPLAY
        );

        assertThat(result.content().readAllBytes()).containsExactly(
                STORED_BYTES
        );
        assertThat(result.contentLength()).isEqualTo(1_024L);
        assertThat(result.contentType()).isEqualTo("image/jpeg");
        assertThat(storageService.requestedKey)
                .isEqualTo(new StorageKey("media/display"));
        assertThat(events).containsExactly(
                "media.findById",
                "memory.findById",
                "participant.find",
                "storage.read"
        );
    }

    @Test
    void shouldDownloadThumbnailUsingTrustedStorageKey() {
        DownloadedMedia result = service.downloadMedia(
                user(),
                MEDIA_ID,
                MediaRepresentation.THUMBNAIL
        );

        assertThat(result.contentLength()).isEqualTo(128L);
        assertThat(storageService.requestedKey)
                .isEqualTo(new StorageKey("media/thumbnail"));
    }

    @ParameterizedTest
    @EnumSource(StoryRole.class)
    void shouldAllowEveryCurrentParticipantRole(StoryRole role) {
        storyParticipantRepository.participant = Optional.of(participant(role));

        DownloadedMedia result = service.downloadMedia(
                user(),
                MEDIA_ID,
                MediaRepresentation.DISPLAY
        );

        assertThat(result.contentType()).isEqualTo("image/jpeg");
        assertThat(storageService.callCount).isEqualTo(1);
    }

    @Test
    void shouldDenyMissingMediaBeforeMemoryOrStorageLookup() {
        mediaFileRepository.mediaFile = Optional.empty();

        assertThatThrownBy(() -> service.downloadMedia(
                user(),
                MEDIA_ID,
                MediaRepresentation.DISPLAY
        )).isInstanceOf(MediaUnavailableException.class)
                .hasMessage("Media could not be found");

        assertThat(events).containsExactly("media.findById");
        assertThat(memoryRepository.callCount).isZero();
        assertThat(storyParticipantRepository.callCount).isZero();
        assertThat(storageService.callCount).isZero();
    }

    @Test
    void shouldDenyMissingMemoryBeforeParticipantOrStorageLookup() {
        memoryRepository.memory = Optional.empty();

        assertThatThrownBy(() -> service.downloadMedia(
                user(),
                MEDIA_ID,
                MediaRepresentation.DISPLAY
        )).isInstanceOf(MediaUnavailableException.class);

        assertThat(events).containsExactly("media.findById", "memory.findById");
        assertThat(storyParticipantRepository.callCount).isZero();
        assertThat(storageService.callCount).isZero();
    }

    @Test
    void shouldDenyMissingParticipantBeforeStorageLookup() {
        storyParticipantRepository.participant = Optional.empty();

        assertThatThrownBy(() -> service.downloadMedia(
                user(),
                MEDIA_ID,
                MediaRepresentation.DISPLAY
        )).isInstanceOf(MediaUnavailableException.class);

        assertThat(events).containsExactly(
                "media.findById",
                "memory.findById",
                "participant.find"
        );
        assertThat(storageService.callCount).isZero();
    }

    @Test
    void shouldDenyWrongParticipantProjectionBeforeStorageLookup() {
        storyParticipantRepository.participant = Optional.of(
                new StoryParticipant(OTHER_STORY_ID, USER_ID, StoryRole.OWNER,
                        BASE_TIME)
        );

        assertThatThrownBy(() -> service.downloadMedia(
                user(),
                MEDIA_ID,
                MediaRepresentation.DISPLAY
        )).isInstanceOf(MediaUnavailableException.class);

        assertThat(storageService.callCount).isZero();
    }

    @Test
    void shouldDenyWrongMembershipUserBeforeStorageLookup() {
        storyParticipantRepository.participant = Optional.of(
                new StoryParticipant(STORY_ID, OTHER_USER_ID, StoryRole.OWNER,
                        BASE_TIME)
        );

        assertThatThrownBy(() -> service.downloadMedia(
                user(),
                MEDIA_ID,
                MediaRepresentation.DISPLAY
        )).isInstanceOf(MediaUnavailableException.class);

        assertThat(storageService.callCount).isZero();
    }

    @Test
    void shouldMapMissingStorageObjectToSafeUnavailable() {
        storageService.failure = new StorageObjectNotFoundException();

        assertThatThrownBy(() -> service.downloadMedia(
                user(),
                MEDIA_ID,
                MediaRepresentation.DISPLAY
        )).isInstanceOf(MediaUnavailableException.class)
                .hasMessage("Media could not be found");
    }

    @Test
    void shouldPropagateTechnicalStorageFailure() {
        StorageException failure = new StorageException();
        storageService.failure = failure;

        assertThatThrownBy(() -> service.downloadMedia(
                user(),
                MEDIA_ID,
                MediaRepresentation.DISPLAY
        )).isSameAs(failure);
    }

    @Test
    void shouldRejectNullDependenciesAndInputs() {
        assertThatThrownBy(() -> new TransactionalDownloadMediaService(
                null,
                memoryRepository,
                storyParticipantRepository,
                storageService
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("mediaFileRepository must not be null");
        assertThatThrownBy(() -> new TransactionalDownloadMediaService(
                mediaFileRepository,
                null,
                storyParticipantRepository,
                storageService
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("memoryRepository must not be null");
        assertThatThrownBy(() -> new TransactionalDownloadMediaService(
                mediaFileRepository,
                memoryRepository,
                null,
                storageService
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("storyParticipantRepository must not be null");
        assertThatThrownBy(() -> new TransactionalDownloadMediaService(
                mediaFileRepository,
                memoryRepository,
                storyParticipantRepository,
                null
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("storageService must not be null");
        assertThatThrownBy(() -> service.downloadMedia(
                null,
                MEDIA_ID,
                MediaRepresentation.DISPLAY
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("authenticatedUser must not be null");
        assertThatThrownBy(() -> service.downloadMedia(
                user(),
                null,
                MediaRepresentation.DISPLAY
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("mediaId must not be null");
        assertThatThrownBy(() -> service.downloadMedia(user(), MEDIA_ID, null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("representation must not be null");
    }

    private static AuthenticatedUser user() {
        return new AuthenticatedUser(USER_ID);
    }

    private static StoryParticipant participant(StoryRole role) {
        return new StoryParticipant(STORY_ID, USER_ID, role, BASE_TIME);
    }

    private static Memory memory() {
        return new Memory(
                MEMORY_ID,
                STORY_ID,
                USER_ID,
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

    private static MediaFile mediaFile() {
        return new MediaFile(
                MEDIA_ID,
                MEMORY_ID,
                MediaType.PHOTO,
                "media/display",
                1_024L,
                "media/thumbnail",
                128L,
                "image/jpeg",
                BASE_TIME
        );
    }

    private static final class FakeMediaFileRepository
            implements MediaFileRepository {

        private final List<String> events;
        private Optional<MediaFile> mediaFile = Optional.of(mediaFile());

        private FakeMediaFileRepository(List<String> events) {
            this.events = events;
        }

        @Override
        public Optional<MediaFile> findById(UUID id) {
            events.add("media.findById");
            return mediaFile;
        }

        @Override
        public List<MediaFile> findByMemoryId(UUID memoryId) {
            throw new UnsupportedOperationException();
        }

        @Override
        public void save(MediaFile mediaFile) {
            throw new UnsupportedOperationException();
        }

        @Override
        public void delete(UUID id) {
            throw new UnsupportedOperationException();
        }
    }

    private static final class FakeMemoryRepository
            implements MemoryRepository {

        private final List<String> events;
        private Optional<Memory> memory = Optional.of(memory());
        private int callCount;

        private FakeMemoryRepository(List<String> events) {
            this.events = events;
        }

        @Override
        public Optional<Memory> findById(UUID id) {
            events.add("memory.findById");
            callCount++;
            return memory;
        }

        @Override
        public Optional<Memory> findByIdForUpdate(UUID id) {
            throw new UnsupportedOperationException();
        }

        @Override
        public List<Memory> findByStoryId(UUID storyId) {
            throw new UnsupportedOperationException();
        }

        @Override
        public void save(Memory memory) {
            throw new UnsupportedOperationException();
        }

        @Override
        public boolean update(Memory memory) {
            throw new UnsupportedOperationException();
        }

        @Override
        public boolean delete(UUID id) {
            throw new UnsupportedOperationException();
        }
    }

    private static final class FakeStoryParticipantRepository
            implements StoryParticipantRepository {

        private final List<String> events;
        private Optional<StoryParticipant> participant =
                Optional.of(participant(StoryRole.OWNER));
        private int callCount;

        private FakeStoryParticipantRepository(List<String> events) {
            this.events = events;
        }

        @Override
        public Optional<StoryParticipant> find(UUID storyId, UUID userId) {
            events.add("participant.find");
            callCount++;
            return participant;
        }

        @Override
        public List<StoryParticipant> findByStoryId(UUID storyId) {
            throw new UnsupportedOperationException();
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

    private static final class FakeStorageService implements StorageService {

        private final List<String> events;
        private StoredObject storedObject = new StoredObject(
                new ByteArrayInputStream(STORED_BYTES),
                STORED_BYTES.length,
                "image/jpeg"
        );
        private RuntimeException failure;
        private StorageKey requestedKey;
        private int callCount;

        private FakeStorageService(List<String> events) {
            this.events = events;
        }

        @Override
        public void store(StorageObjectWrite object) {
            throw new UnsupportedOperationException();
        }

        @Override
        public StoredObject read(StorageKey storageKey) {
            events.add("storage.read");
            requestedKey = storageKey;
            callCount++;

            if (failure != null) {
                throw failure;
            }

            return storedObject;
        }

        @Override
        public void delete(StorageKey storageKey) {
            throw new UnsupportedOperationException();
        }
    }
}
