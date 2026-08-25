package memory_map.backend.media.application;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.media.domain.MediaFile;
import memory_map.backend.media.domain.MediaType;
import memory_map.backend.media.image.ImageProcessingException;
import memory_map.backend.media.image.ImageProcessingInput;
import memory_map.backend.media.image.ImageProcessor;
import memory_map.backend.media.image.InvalidImageException;
import memory_map.backend.media.image.InvalidImageReason;
import memory_map.backend.media.image.ProcessedImage;
import memory_map.backend.media.image.ProcessedPhoto;
import memory_map.backend.media.repository.MediaFileRepository;
import memory_map.backend.media.storage.MediaStorageKeyFactory;
import memory_map.backend.media.storage.MediaStorageKeys;
import memory_map.backend.media.storage.StorageByteRange;
import memory_map.backend.media.storage.StorageKey;
import memory_map.backend.media.storage.StorageObjectWrite;
import memory_map.backend.media.storage.StorageService;
import memory_map.backend.media.storage.StoredObject;
import memory_map.backend.memory.domain.Memory;
import memory_map.backend.memory.repository.MemoryRepository;
import memory_map.backend.storyparticipant.domain.StoryParticipant;
import memory_map.backend.storyparticipant.domain.StoryRole;
import memory_map.backend.storyparticipant.repository.StoryParticipantRepository;
import org.junit.jupiter.api.Test;

import java.io.ByteArrayInputStream;
import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class CoordinatedUploadPhotoServiceTest {

    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID OWNER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000002");
    private static final UUID AUTHOR_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000003");
    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000011");
    private static final UUID MEMORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000021");
    private static final UUID MEDIA_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000031");
    private static final Instant BASE_TIME =
            Instant.parse("2026-01-01T10:00:00Z");
    private static final Instant CURRENT_TIME =
            Instant.parse("2026-01-10T10:00:00Z");
    private static final ImageProcessingInput IMAGE =
            new ImageProcessingInput(new byte[] {1, 2, 3}, "image/png");
    private static final byte[] DISPLAY_BYTES = new byte[] {10, 11, 12, 13};
    private static final byte[] THUMBNAIL_BYTES = new byte[] {20, 21};
    private static final ProcessedPhoto PROCESSED_PHOTO =
            new ProcessedPhoto(
                    new ProcessedImage(DISPLAY_BYTES),
                    new ProcessedImage(THUMBNAIL_BYTES),
                    "image/jpeg"
            );

    private final List<String> events = new ArrayList<>();
    private final FakeMemoryRepository memoryRepository =
            new FakeMemoryRepository(events);
    private final FakeStoryParticipantRepository storyParticipantRepository =
            new FakeStoryParticipantRepository(events);
    private final FakeMediaFileRepository mediaFileRepository =
            new FakeMediaFileRepository(events);
    private final PhotoUploadAuthorizationPolicy authorizationPolicy =
            new PhotoUploadAuthorizationPolicy();
    private final FakeImageProcessor imageProcessor =
            new FakeImageProcessor(events);
    private final FakeMediaStorageKeyFactory storageKeyFactory =
            new FakeMediaStorageKeyFactory(events);
    private final FakeStorageService storageService =
            new FakeStorageService(events);
    private final FakeRollbackCoordinator rollbackCoordinator =
            new FakeRollbackCoordinator(events);
    private final CoordinatedUploadPhotoService service =
            new CoordinatedUploadPhotoService(
                    memoryRepository,
                    storyParticipantRepository,
                    mediaFileRepository,
                    authorizationPolicy,
                    imageProcessor,
                    storageKeyFactory,
                    storageService,
                    rollbackCoordinator
            );

    @Test
    void shouldUploadPhotoForOwner() {
        arrangeCurrentMemory(AUTHOR_ID);
        arrangeCurrentParticipant(USER_ID, StoryRole.OWNER);

        MediaFile result = service.uploadPhoto(command(USER_ID));

        assertThat(result).isEqualTo(expectedMediaFile());
        assertThat(mediaFileRepository.savedMediaFile)
                .isEqualTo(expectedMediaFile());
        assertThat(memoryRepository.requestedId).isEqualTo(MEMORY_ID);
        assertThat(storyParticipantRepository.requestedStoryId)
                .isEqualTo(STORY_ID);
        assertThat(storyParticipantRepository.requestedUserId)
                .isEqualTo(USER_ID);
        assertThat(storageService.storedObjects)
                .containsOnlyKeys(displayKey(), thumbnailKey());
        assertStoredObject(displayKey(), DISPLAY_BYTES);
        assertStoredObject(thumbnailKey(), THUMBNAIL_BYTES);
        assertThat(rollbackCoordinator.actions).hasSize(1);
        assertThat(events).containsExactly(
                "memory.findByIdForUpdate",
                "participant.find",
                "image.process",
                "keys.keysFor",
                "storage.store:display",
                "storage.store:thumbnail",
                "rollback.register",
                "media.save"
        );
    }

    @Test
    void shouldUploadPhotoForCoOwner() {
        arrangeCurrentMemory(AUTHOR_ID);
        arrangeCurrentParticipant(USER_ID, StoryRole.CO_OWNER);

        MediaFile result = service.uploadPhoto(command(USER_ID));

        assertThat(result).isEqualTo(expectedMediaFile());
        assertThat(mediaFileRepository.savedMediaFile)
                .isEqualTo(expectedMediaFile());
    }

    @Test
    void shouldUploadOwnPhotoForEditor() {
        arrangeCurrentMemory(USER_ID);
        arrangeCurrentParticipant(USER_ID, StoryRole.EDITOR);

        MediaFile result = service.uploadPhoto(command(USER_ID));

        assertThat(result).isEqualTo(expectedMediaFile());
    }

    @Test
    void shouldUploadOwnPhotoForViewer() {
        arrangeCurrentMemory(USER_ID);
        arrangeCurrentParticipant(USER_ID, StoryRole.VIEWER);

        MediaFile result = service.uploadPhoto(command(USER_ID));

        assertThat(result).isEqualTo(expectedMediaFile());
    }

    @Test
    void shouldDenyEditorForAnotherAuthorsMemoryBeforeProcessing() {
        assertDeniedRoleBeforeProcessing(StoryRole.EDITOR);
    }

    @Test
    void shouldDenyViewerForAnotherAuthorsMemoryBeforeProcessing() {
        assertDeniedRoleBeforeProcessing(StoryRole.VIEWER);
    }

    @Test
    void shouldThrowUnavailableWhenMemoryIsMissingBeforeAnyOtherWork() {
        memoryRepository.memory = Optional.empty();

        assertThatThrownBy(() -> service.uploadPhoto(command(USER_ID)))
                .isInstanceOf(PhotoUploadUnavailableException.class)
                .hasMessage("Photo could not be uploaded");

        assertNoImageStorageOrSaveWork();
        assertThat(events).containsExactly("memory.findByIdForUpdate");
    }

    @Test
    void shouldThrowUnavailableWhenMembershipIsMissingBeforeProcessing() {
        arrangeCurrentMemory(AUTHOR_ID);
        storyParticipantRepository.participant = Optional.empty();

        assertThatThrownBy(() -> service.uploadPhoto(command(USER_ID)))
                .isInstanceOf(PhotoUploadUnavailableException.class)
                .hasMessage("Photo could not be uploaded");

        assertNoImageStorageOrSaveWork();
        assertThat(events).containsExactly(
                "memory.findByIdForUpdate",
                "participant.find"
        );
    }

    @Test
    void shouldPropagateInvalidImageAndNotStoreAnything() {
        arrangeCurrentMemory(AUTHOR_ID);
        arrangeCurrentParticipant(USER_ID, StoryRole.OWNER);
        InvalidImageException failure = new InvalidImageException(
                InvalidImageReason.INVALID_IMAGE
        );
        imageProcessor.failure = failure;

        assertThatThrownBy(() -> service.uploadPhoto(command(USER_ID)))
                .isSameAs(failure);

        assertThat(storageService.storedObjects).isEmpty();
        assertThat(mediaFileRepository.savedMediaFile).isNull();
        assertThat(events).containsExactly(
                "memory.findByIdForUpdate",
                "participant.find",
                "image.process"
        );
    }

    @Test
    void shouldPropagateImageProcessingFailureAndNotStoreAnything() {
        arrangeCurrentMemory(AUTHOR_ID);
        arrangeCurrentParticipant(USER_ID, StoryRole.OWNER);
        ImageProcessingException failure = new ImageProcessingException();
        imageProcessor.failure = failure;

        assertThatThrownBy(() -> service.uploadPhoto(command(USER_ID)))
                .isSameAs(failure);

        assertThat(storageService.storedObjects).isEmpty();
        assertThat(mediaFileRepository.savedMediaFile).isNull();
    }

    @Test
    void shouldPropagateDisplayStoreFailureWithoutThumbnailOrDbSave() {
        arrangeCurrentMemory(AUTHOR_ID);
        arrangeCurrentParticipant(USER_ID, StoryRole.OWNER);
        RuntimeException failure = new RuntimeException("display store failed");
        storageService.storeFailures.put(displayKey(), failure);

        assertThatThrownBy(() -> service.uploadPhoto(command(USER_ID)))
                .isSameAs(failure);

        assertThat(storageService.storedObjects).isEmpty();
        assertThat(storageService.deletedKeys).isEmpty();
        assertThat(mediaFileRepository.savedMediaFile).isNull();
        assertThat(events).containsExactly(
                "memory.findByIdForUpdate",
                "participant.find",
                "image.process",
                "keys.keysFor",
                "storage.store:display"
        );
    }

    @Test
    void shouldCleanupDisplayAndPreserveThumbnailFailureAsPrimary() {
        arrangeCurrentMemory(AUTHOR_ID);
        arrangeCurrentParticipant(USER_ID, StoryRole.OWNER);
        RuntimeException failure = new RuntimeException(
                "thumbnail store failed"
        );
        storageService.storeFailures.put(thumbnailKey(), failure);

        assertThatThrownBy(() -> service.uploadPhoto(command(USER_ID)))
                .isSameAs(failure)
                .satisfies(exception -> assertThat(
                        exception.getSuppressed()
                ).isEmpty());

        assertThat(storageService.deletedKeys).containsExactly(displayKey());
        assertThat(mediaFileRepository.savedMediaFile).isNull();
        assertThat(events).containsExactly(
                "memory.findByIdForUpdate",
                "participant.find",
                "image.process",
                "keys.keysFor",
                "storage.store:display",
                "storage.store:thumbnail",
                "storage.delete:display"
        );
    }

    @Test
    void shouldSuppressDisplayCleanupFailureWhenThumbnailStoreFails() {
        arrangeCurrentMemory(AUTHOR_ID);
        arrangeCurrentParticipant(USER_ID, StoryRole.OWNER);
        RuntimeException thumbnailFailure = new RuntimeException(
                "thumbnail store failed"
        );
        RuntimeException cleanupFailure = new RuntimeException(
                "display cleanup failed"
        );
        storageService.storeFailures.put(thumbnailKey(), thumbnailFailure);
        storageService.deleteFailures.put(displayKey(), cleanupFailure);

        assertThatThrownBy(() -> service.uploadPhoto(command(USER_ID)))
                .isSameAs(thumbnailFailure)
                .satisfies(exception -> assertThat(
                        exception.getSuppressed()
                ).containsExactly(cleanupFailure));
    }

    @Test
    void shouldRegisterRollbackCleanupBeforeSavingMetadata() {
        arrangeCurrentMemory(AUTHOR_ID);
        arrangeCurrentParticipant(USER_ID, StoryRole.OWNER);

        service.uploadPhoto(command(USER_ID));
        rollbackCoordinator.runFirstAction();

        assertThat(storageService.deletedKeys)
                .containsExactly(thumbnailKey(), displayKey());
        assertThat(events).containsExactly(
                "memory.findByIdForUpdate",
                "participant.find",
                "image.process",
                "keys.keysFor",
                "storage.store:display",
                "storage.store:thumbnail",
                "rollback.register",
                "media.save",
                "storage.delete:thumbnail",
                "storage.delete:display"
        );
    }

    @Test
    void shouldPropagateDbFailureAndLeaveRollbackActionRegistered() {
        arrangeCurrentMemory(AUTHOR_ID);
        arrangeCurrentParticipant(USER_ID, StoryRole.OWNER);
        RuntimeException failure = new RuntimeException("db save failed");
        mediaFileRepository.saveFailure = failure;

        assertThatThrownBy(() -> service.uploadPhoto(command(USER_ID)))
                .isSameAs(failure);

        assertThat(rollbackCoordinator.actions).hasSize(1);
        rollbackCoordinator.runFirstAction();
        assertThat(storageService.deletedKeys)
                .containsExactly(thumbnailKey(), displayKey());
    }

    @Test
    void shouldCleanupBothObjectsWhenRollbackRegistrationFails() {
        arrangeCurrentMemory(AUTHOR_ID);
        arrangeCurrentParticipant(USER_ID, StoryRole.OWNER);
        RuntimeException failure = new RuntimeException(
                "rollback registration failed"
        );
        rollbackCoordinator.failure = failure;

        assertThatThrownBy(() -> service.uploadPhoto(command(USER_ID)))
                .isSameAs(failure);

        assertThat(storageService.deletedKeys)
                .containsExactly(thumbnailKey(), displayKey());
        assertThat(mediaFileRepository.savedMediaFile).isNull();
    }

    @Test
    void shouldSuppressCleanupFailuresWhenRollbackRegistrationFails() {
        arrangeCurrentMemory(AUTHOR_ID);
        arrangeCurrentParticipant(USER_ID, StoryRole.OWNER);
        RuntimeException registrationFailure = new RuntimeException(
                "rollback registration failed"
        );
        RuntimeException thumbnailCleanupFailure = new RuntimeException(
                "thumbnail cleanup failed"
        );
        RuntimeException displayCleanupFailure = new RuntimeException(
                "display cleanup failed"
        );
        rollbackCoordinator.failure = registrationFailure;
        storageService.deleteFailures.put(
                thumbnailKey(),
                thumbnailCleanupFailure
        );
        storageService.deleteFailures.put(displayKey(), displayCleanupFailure);

        assertThatThrownBy(() -> service.uploadPhoto(command(USER_ID)))
                .isSameAs(registrationFailure)
                .satisfies(exception -> assertThat(
                        exception.getSuppressed()
                ).containsExactly(
                        thumbnailCleanupFailure,
                        displayCleanupFailure
                ));
    }

    @Test
    void shouldRejectNullDependencies() {
        assertThatThrownBy(() -> new CoordinatedUploadPhotoService(
                null,
                storyParticipantRepository,
                mediaFileRepository,
                authorizationPolicy,
                imageProcessor,
                storageKeyFactory,
                storageService,
                rollbackCoordinator
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("memoryRepository must not be null");

        assertThatThrownBy(() -> new CoordinatedUploadPhotoService(
                memoryRepository,
                null,
                mediaFileRepository,
                authorizationPolicy,
                imageProcessor,
                storageKeyFactory,
                storageService,
                rollbackCoordinator
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("storyParticipantRepository must not be null");

        assertThatThrownBy(() -> new CoordinatedUploadPhotoService(
                memoryRepository,
                storyParticipantRepository,
                null,
                authorizationPolicy,
                imageProcessor,
                storageKeyFactory,
                storageService,
                rollbackCoordinator
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("mediaFileRepository must not be null");

        assertThatThrownBy(() -> new CoordinatedUploadPhotoService(
                memoryRepository,
                storyParticipantRepository,
                mediaFileRepository,
                null,
                imageProcessor,
                storageKeyFactory,
                storageService,
                rollbackCoordinator
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("authorizationPolicy must not be null");

        assertThatThrownBy(() -> new CoordinatedUploadPhotoService(
                memoryRepository,
                storyParticipantRepository,
                mediaFileRepository,
                authorizationPolicy,
                null,
                storageKeyFactory,
                storageService,
                rollbackCoordinator
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("imageProcessor must not be null");

        assertThatThrownBy(() -> new CoordinatedUploadPhotoService(
                memoryRepository,
                storyParticipantRepository,
                mediaFileRepository,
                authorizationPolicy,
                imageProcessor,
                null,
                storageService,
                rollbackCoordinator
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("storageKeyFactory must not be null");

        assertThatThrownBy(() -> new CoordinatedUploadPhotoService(
                memoryRepository,
                storyParticipantRepository,
                mediaFileRepository,
                authorizationPolicy,
                imageProcessor,
                storageKeyFactory,
                null,
                rollbackCoordinator
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("storageService must not be null");

        assertThatThrownBy(() -> new CoordinatedUploadPhotoService(
                memoryRepository,
                storyParticipantRepository,
                mediaFileRepository,
                authorizationPolicy,
                imageProcessor,
                storageKeyFactory,
                storageService,
                null
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("rollbackCoordinator must not be null");
    }

    @Test
    void shouldRejectNullCommandBeforeRepositoryCalls() {
        assertThatThrownBy(() -> service.uploadPhoto(null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("command must not be null");

        assertThat(events).isEmpty();
    }

    private void assertDeniedRoleBeforeProcessing(StoryRole role) {
        arrangeCurrentMemory(AUTHOR_ID);
        arrangeCurrentParticipant(USER_ID, role);

        assertThatThrownBy(() -> service.uploadPhoto(command(USER_ID)))
                .isInstanceOf(PhotoUploadUnavailableException.class)
                .hasMessage("Photo could not be uploaded");

        assertNoImageStorageOrSaveWork();
        assertThat(events).containsExactly(
                "memory.findByIdForUpdate",
                "participant.find"
        );
    }

    private void assertNoImageStorageOrSaveWork() {
        assertThat(imageProcessor.processedInputs).isEmpty();
        assertThat(storageKeyFactory.requestedMediaId).isNull();
        assertThat(storageService.storedObjects).isEmpty();
        assertThat(mediaFileRepository.savedMediaFile).isNull();
        assertThat(rollbackCoordinator.actions).isEmpty();
    }

    private void assertStoredObject(StorageKey key, byte[] expectedContent) {
        StorageObjectWrite object = storageService.storedObjects.get(key);

        assertThat(object.storageKey()).isEqualTo(key);
        assertThat(object.content()).containsExactly(expectedContent);
        assertThat(object.contentLength()).isEqualTo(expectedContent.length);
        assertThat(object.contentType()).isEqualTo("image/jpeg");
    }

    private void arrangeCurrentMemory(UUID createdBy) {
        memoryRepository.memory = Optional.of(memory(createdBy));
    }

    private void arrangeCurrentParticipant(UUID userId, StoryRole role) {
        storyParticipantRepository.participant = Optional.of(
                new StoryParticipant(STORY_ID, userId, role, BASE_TIME)
        );
    }

    private static UploadPhotoCommand command(UUID userId) {
        return new UploadPhotoCommand(
                new AuthenticatedUser(userId),
                MEMORY_ID,
                MEDIA_ID,
                IMAGE,
                CURRENT_TIME
        );
    }

    private static MediaFile expectedMediaFile() {
        return new MediaFile(
                MEDIA_ID,
                MEMORY_ID,
                MediaType.PHOTO,
                displayKey().value(),
                DISPLAY_BYTES.length,
                thumbnailKey().value(),
                THUMBNAIL_BYTES.length,
                "image/jpeg",
                CURRENT_TIME
        );
    }

    private static Memory memory(UUID createdBy) {
        return new Memory(
                MEMORY_ID,
                STORY_ID,
                createdBy,
                "First trip",
                "A spring walk",
                "Tbilisi",
                41.715137,
                44.827096,
                LocalDate.of(2024, 5, 18),
                BASE_TIME,
                BASE_TIME
        );
    }

    private static StorageKey displayKey() {
        return new StorageKey("media/" + MEDIA_ID + "/display");
    }

    private static StorageKey thumbnailKey() {
        return new StorageKey("media/" + MEDIA_ID + "/thumbnail");
    }

    private static final class FakeMemoryRepository
            implements MemoryRepository {

        private final List<String> events;
        private Optional<Memory> memory = Optional.empty();
        private UUID requestedId;

        private FakeMemoryRepository(List<String> events) {
            this.events = events;
        }

        @Override
        public Optional<Memory> findById(UUID id) {
            throw new UnsupportedOperationException();
        }

        @Override
        public Optional<Memory> findByIdForUpdate(UUID id) {
            events.add("memory.findByIdForUpdate");
            requestedId = id;
            return memory;
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
        private Optional<StoryParticipant> participant = Optional.empty();
        private UUID requestedStoryId;
        private UUID requestedUserId;

        private FakeStoryParticipantRepository(List<String> events) {
            this.events = events;
        }

        @Override
        public Optional<StoryParticipant> find(UUID storyId, UUID userId) {
            events.add("participant.find");
            requestedStoryId = storyId;
            requestedUserId = userId;
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

    private static final class FakeMediaFileRepository
            implements MediaFileRepository {

        private final List<String> events;
        private MediaFile savedMediaFile;
        private RuntimeException saveFailure;

        private FakeMediaFileRepository(List<String> events) {
            this.events = events;
        }

        @Override
        public Optional<MediaFile> findById(UUID id) {
            throw new UnsupportedOperationException();
        }

        @Override
        public List<MediaFile> findByMemoryId(UUID memoryId) {
            throw new UnsupportedOperationException();
        }

        @Override
        public void save(MediaFile mediaFile) {
            events.add("media.save");
            savedMediaFile = mediaFile;

            if (saveFailure != null) {
                throw saveFailure;
            }
        }

        @Override
        public void delete(UUID id) {
            throw new UnsupportedOperationException();
        }
    }

    private static final class FakeImageProcessor implements ImageProcessor {

        private final List<String> events;
        private final List<ImageProcessingInput> processedInputs =
                new ArrayList<>();
        private RuntimeException failure;

        private FakeImageProcessor(List<String> events) {
            this.events = events;
        }

        @Override
        public ProcessedPhoto process(ImageProcessingInput input) {
            events.add("image.process");
            processedInputs.add(input);

            if (failure != null) {
                throw failure;
            }

            return PROCESSED_PHOTO;
        }
    }

    private static final class FakeMediaStorageKeyFactory
            implements MediaStorageKeyFactory {

        private final List<String> events;
        private UUID requestedMediaId;

        private FakeMediaStorageKeyFactory(List<String> events) {
            this.events = events;
        }

        @Override
        public MediaStorageKeys keysFor(UUID mediaId) {
            events.add("keys.keysFor");
            requestedMediaId = mediaId;
            return new MediaStorageKeys(displayKey(), thumbnailKey());
        }
    }

    private static final class FakeStorageService implements StorageService {

        private final List<String> events;
        private final Map<StorageKey, StorageObjectWrite> storedObjects =
                new LinkedHashMap<>();
        private final List<StorageKey> deletedKeys = new ArrayList<>();
        private final Map<StorageKey, RuntimeException> storeFailures =
                new LinkedHashMap<>();
        private final Map<StorageKey, RuntimeException> deleteFailures =
                new LinkedHashMap<>();

        private FakeStorageService(List<String> events) {
            this.events = events;
        }

        @Override
        public void store(StorageObjectWrite object) {
            events.add("storage.store:" + label(object.storageKey()));

            RuntimeException failure = storeFailures.get(object.storageKey());
            if (failure != null) {
                throw failure;
            }

            storedObjects.put(object.storageKey(), object);
        }

        @Override
        public StoredObject read(StorageKey storageKey) {
            StorageObjectWrite object = storedObjects.get(storageKey);

            return new StoredObject(
                    new ByteArrayInputStream(object.content()),
                    object.contentLength(),
                    object.contentType()
            );
        }

        @Override
        public StoredObject readRange(
                StorageKey storageKey,
                StorageByteRange range
        ) {
            throw new UnsupportedOperationException();
        }

        @Override
        public void delete(StorageKey storageKey) {
            events.add("storage.delete:" + label(storageKey));
            deletedKeys.add(storageKey);

            RuntimeException failure = deleteFailures.get(storageKey);
            if (failure != null) {
                throw failure;
            }

            storedObjects.remove(storageKey);
        }

        private static String label(StorageKey key) {
            if (Objects.equals(key, displayKey())) {
                return "display";
            }

            if (Objects.equals(key, thumbnailKey())) {
                return "thumbnail";
            }

            return "unknown";
        }
    }

    private static final class FakeRollbackCoordinator
            implements TransactionRollbackCoordinator {

        private final List<String> events;
        private final List<Runnable> actions = new ArrayList<>();
        private RuntimeException failure;

        private FakeRollbackCoordinator(List<String> events) {
            this.events = events;
        }

        @Override
        public void onRollback(Runnable action) {
            events.add("rollback.register");

            if (failure != null) {
                throw failure;
            }

            actions.add(action);
        }

        private void runFirstAction() {
            actions.get(0).run();
        }
    }
}
