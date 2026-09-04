package memory_map.backend.media.application;

import memory_map.backend.IntegrationTest;
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
import memory_map.backend.media.repository.JdbcMediaFileRepository;
import memory_map.backend.media.repository.MediaFileRepository;
import memory_map.backend.media.storage.MediaStorageKeyFactory;
import memory_map.backend.media.storage.StorageByteRange;
import memory_map.backend.media.storage.StorageKey;
import memory_map.backend.media.storage.StorageObjectWrite;
import memory_map.backend.media.storage.StorageService;
import memory_map.backend.media.storage.StoredObject;
import memory_map.backend.memory.domain.Memory;
import memory_map.backend.memory.repository.MemoryRepository;
import memory_map.backend.notification.application.NotificationPublisher;
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
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.context.annotation.Primary;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

import java.io.ByteArrayInputStream;
import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

@Import(UploadPhotoUseCaseIntegrationTest.UploadPhotoUseCaseTestConfiguration.class)
class UploadPhotoUseCaseIntegrationTest extends IntegrationTest {

    @Autowired
    private UploadPhotoUseCase uploadPhotoUseCase;

    @Autowired
    private MemoryRepository memoryRepository;

    @Autowired
    private TestMediaFileRepository mediaFileRepository;

    @Autowired
    private TestImageProcessor imageProcessor;

    @Autowired
    private TestStorageService storageService;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private StoryRepository storyRepository;

    @Autowired
    private StoryParticipantRepository storyParticipantRepository;

    @Autowired
    private PlatformTransactionManager transactionManager;

    @Autowired
    private JdbcClient jdbcClient;

    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID OWNER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000002");
    private static final UUID AUTHOR_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000003");
    private static final UUID OUTSIDER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000004");
    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000011");
    private static final UUID OTHER_STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000012");
    private static final UUID MEMORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000021");
    private static final UUID MEDIA_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000031");
    private static final UUID SECOND_MEDIA_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000032");
    private static final Instant BASE_TIME =
            Instant.parse("2026-01-01T10:00:00.123456Z");
    private static final Instant CURRENT_TIME =
            Instant.parse("2026-01-10T10:00:00.123456Z");
    private static final LocalDate EVENT_DATE =
            LocalDate.of(2024, 5, 20);
    private static final ImageProcessingInput IMAGE =
            new ImageProcessingInput(new byte[] {1, 2, 3, 4}, "image/png");
    private static final byte[] DISPLAY_BYTES = new byte[] {10, 11, 12, 13};
    private static final byte[] THUMBNAIL_BYTES = new byte[] {20, 21};
    private static final String CLEAN_DATABASE_SQL = """
        TRUNCATE TABLE users
        RESTART IDENTITY CASCADE
        """;

    @BeforeEach
    void cleanDatabaseAndFakes() {
        mediaFileRepository.reset();
        imageProcessor.reset();
        storageService.reset();
        jdbcClient.sql(CLEAN_DATABASE_SQL).update();
    }

    @Test
    void shouldUploadPhotoForOwnerAndPersistMetadata() {
        User owner = saveUser(OWNER_ID, "owner-google-subject");
        User author = saveUser(AUTHOR_ID, "author-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        Memory memory = saveMemory(MEMORY_ID, story.id(), author.id());

        MediaFile result = uploadPhotoUseCase.uploadPhoto(command(
                owner.id(),
                memory.id(),
                MEDIA_ID
        ));

        MediaFile expected = expectedMediaFile(MEDIA_ID, memory.id());

        assertThat(result).isEqualTo(expected);
        assertThat(mediaFileRepository.findById(MEDIA_ID)).contains(expected);
        assertThat(storageService.objects).containsOnlyKeys(
                displayKey(MEDIA_ID),
                thumbnailKey(MEDIA_ID)
        );
        assertStoredObject(displayKey(MEDIA_ID), DISPLAY_BYTES);
        assertStoredObject(thumbnailKey(MEDIA_ID), THUMBNAIL_BYTES);
        assertThat(imageProcessor.inputs).containsExactly(IMAGE);
    }

    @Test
    void shouldUploadPhotoForCoOwnerWithoutChangingMemoryOwner() {
        User owner = saveUser(OWNER_ID, "owner-google-subject");
        User coOwner = saveUser(USER_ID, "co-owner-google-subject");
        User author = saveUser(AUTHOR_ID, "author-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(story.id(), coOwner.id(), StoryRole.CO_OWNER);
        Memory memory = saveMemory(MEMORY_ID, story.id(), author.id());

        MediaFile result = uploadPhotoUseCase.uploadPhoto(command(
                coOwner.id(),
                memory.id(),
                MEDIA_ID
        ));

        assertThat(result.memoryId()).isEqualTo(memory.id());
        assertThat(memoryRepository.findById(memory.id()))
                .contains(memory);
    }

    @Test
    void shouldUploadOwnPhotoForEditor() {
        assertAuthorRoleCanUploadOwnPhoto(StoryRole.EDITOR);
    }

    @Test
    void shouldDenyViewerAuthorWithoutProcessingOrStorage() {
        assertDeniedAuthorRoleKeepsSystemUnchanged(StoryRole.VIEWER);
    }

    @Test
    void shouldDenyEditorForAnotherAuthorsMemoryWithoutProcessingOrStorage() {
        assertDeniedRoleKeepsSystemUnchanged(StoryRole.EDITOR);
    }

    @Test
    void shouldDenyViewerForAnotherAuthorsMemoryWithoutProcessingOrStorage() {
        assertDeniedRoleKeepsSystemUnchanged(StoryRole.VIEWER);
    }

    @Test
    void shouldThrowUnavailableWhenMemoryIsMissing() {
        User user = saveUser(USER_ID, "current-google-subject");

        assertPhotoUnavailable(() -> uploadPhotoUseCase.uploadPhoto(command(
                user.id(),
                MEMORY_ID,
                MEDIA_ID
        )));

        assertNoProcessingStorageOrMetadata();
    }

    @Test
    void shouldThrowUnavailableWhenMemoryIsInaccessible() {
        User owner = saveUser(OWNER_ID, "owner-google-subject");
        User outsider = saveUser(OUTSIDER_ID, "outsider-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        Memory memory = saveMemory(MEMORY_ID, story.id(), owner.id());

        assertPhotoUnavailable(() -> uploadPhotoUseCase.uploadPhoto(command(
                outsider.id(),
                memory.id(),
                MEDIA_ID
        )));

        assertThat(memoryRepository.findById(memory.id())).contains(memory);
        assertNoProcessingStorageOrMetadata();
    }

    @Test
    void shouldDenyFormerAuthorWithoutMembership() {
        User owner = saveUser(OWNER_ID, "owner-google-subject");
        User author = saveUser(AUTHOR_ID, "author-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        Memory memory = saveMemory(MEMORY_ID, story.id(), author.id());

        PhotoUploadUnavailableException denied =
                catchPhotoUnavailable(() -> uploadPhotoUseCase.uploadPhoto(
                        command(author.id(), memory.id(), MEDIA_ID)
                ));
        PhotoUploadUnavailableException missing =
                catchPhotoUnavailable(() -> uploadPhotoUseCase.uploadPhoto(
                        command(author.id(), OTHER_STORY_ID, SECOND_MEDIA_ID)
                ));

        assertThat(denied.getClass()).isEqualTo(missing.getClass());
        assertThat(denied.getMessage())
                .isEqualTo(missing.getMessage())
                .isEqualTo("Photo could not be uploaded");
        assertNoProcessingStorageOrMetadata();
    }

    @Test
    void shouldDenyParticipantOfAnotherStory() {
        User owner = saveUser(OWNER_ID, "owner-google-subject");
        User user = saveUser(USER_ID, "current-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        Story otherStory = saveStory(OTHER_STORY_ID, owner.id());
        saveParticipant(otherStory.id(), user.id(), StoryRole.OWNER);
        Memory memory = saveMemory(MEMORY_ID, story.id(), owner.id());

        assertPhotoUnavailable(() -> uploadPhotoUseCase.uploadPhoto(command(
                user.id(),
                memory.id(),
                MEDIA_ID
        )));

        assertNoProcessingStorageOrMetadata();
    }

    @Test
    void shouldPropagateInvalidImageWithoutStorageOrMetadata() {
        User owner = saveUser(OWNER_ID, "owner-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        Memory memory = saveMemory(MEMORY_ID, story.id(), owner.id());
        InvalidImageException failure = new InvalidImageException(
                InvalidImageReason.INVALID_IMAGE
        );
        imageProcessor.failure = failure;

        assertThatThrownBy(() -> uploadPhotoUseCase.uploadPhoto(command(
                owner.id(),
                memory.id(),
                MEDIA_ID
        ))).isSameAs(failure);

        assertThat(storageService.objects).isEmpty();
        assertThat(mediaFileRepository.findById(MEDIA_ID)).isEmpty();
    }

    @Test
    void shouldPropagateProcessingFailureWithoutStorageOrMetadata() {
        User owner = saveUser(OWNER_ID, "owner-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        Memory memory = saveMemory(MEMORY_ID, story.id(), owner.id());
        ImageProcessingException failure = new ImageProcessingException();
        imageProcessor.failure = failure;

        assertThatThrownBy(() -> uploadPhotoUseCase.uploadPhoto(command(
                owner.id(),
                memory.id(),
                MEDIA_ID
        ))).isSameAs(failure);

        assertThat(storageService.objects).isEmpty();
        assertThat(mediaFileRepository.findById(MEDIA_ID)).isEmpty();
    }

    @Test
    void shouldCleanupDisplayWhenThumbnailStoreFails() {
        User owner = saveUser(OWNER_ID, "owner-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        Memory memory = saveMemory(MEMORY_ID, story.id(), owner.id());
        RuntimeException thumbnailFailure = new RuntimeException(
                "thumbnail store failed"
        );
        storageService.failStoreFor(thumbnailKey(MEDIA_ID), thumbnailFailure);

        assertThatThrownBy(() -> uploadPhotoUseCase.uploadPhoto(command(
                owner.id(),
                memory.id(),
                MEDIA_ID
        ))).isSameAs(thumbnailFailure);

        assertThat(storageService.objects).isEmpty();
        assertThat(storageService.deletedKeys)
                .containsExactly(displayKey(MEDIA_ID));
        assertThat(mediaFileRepository.findById(MEDIA_ID)).isEmpty();
    }

    @Test
    void shouldCleanupBothStorageObjectsWhenMetadataSaveFails() {
        User owner = saveUser(OWNER_ID, "owner-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        Memory memory = saveMemory(MEMORY_ID, story.id(), owner.id());
        mediaFileRepository.failAfterSave(
                new RuntimeException("media save failed after insert")
        );

        assertThatThrownBy(() -> uploadPhotoUseCase.uploadPhoto(command(
                owner.id(),
                memory.id(),
                MEDIA_ID
        )))
                .isInstanceOf(RuntimeException.class)
                .hasMessage("media save failed after insert");

        assertThat(mediaFileRepository.findById(MEDIA_ID)).isEmpty();
        assertThat(storageService.objects).isEmpty();
        assertThat(storageService.deletedKeys)
                .containsExactly(thumbnailKey(MEDIA_ID), displayKey(MEDIA_ID));
    }

    @Test
    void shouldCleanupStorageWhenOuterTransactionRollsBackAfterSuccess() {
        User owner = saveUser(OWNER_ID, "owner-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        Memory memory = saveMemory(MEMORY_ID, story.id(), owner.id());
        TransactionTemplate transactionTemplate =
                new TransactionTemplate(transactionManager);

        MediaFile result = transactionTemplate.execute(status -> {
            MediaFile mediaFile = uploadPhotoUseCase.uploadPhoto(command(
                    owner.id(),
                    memory.id(),
                    MEDIA_ID
            ));
            assertThat(mediaFileRepository.findById(MEDIA_ID))
                    .contains(mediaFile);
            assertThat(storageService.objects).hasSize(2);

            status.setRollbackOnly();

            return mediaFile;
        });

        assertThat(result).isEqualTo(expectedMediaFile(MEDIA_ID, memory.id()));
        assertThat(mediaFileRepository.findById(MEDIA_ID)).isEmpty();
        assertThat(storageService.objects).isEmpty();
        assertThat(storageService.deletedKeys)
                .containsExactly(thumbnailKey(MEDIA_ID), displayKey(MEDIA_ID));
    }

    private void assertAuthorRoleCanUploadOwnPhoto(StoryRole role) {
        User owner = saveUser(OWNER_ID, "owner-google-subject");
        User author = saveUser(USER_ID, "author-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(story.id(), author.id(), role);
        Memory memory = saveMemory(MEMORY_ID, story.id(), author.id());

        MediaFile result = uploadPhotoUseCase.uploadPhoto(command(
                author.id(),
                memory.id(),
                MEDIA_ID
        ));

        assertThat(result).isEqualTo(expectedMediaFile(MEDIA_ID, memory.id()));
        assertThat(mediaFileRepository.findById(MEDIA_ID)).contains(result);
    }

    private void assertDeniedRoleKeepsSystemUnchanged(StoryRole role) {
        User owner = saveUser(OWNER_ID, "owner-google-subject");
        User participant = saveUser(USER_ID, "current-google-subject");
        User author = saveUser(AUTHOR_ID, "author-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(story.id(), participant.id(), role);
        Memory memory = saveMemory(MEMORY_ID, story.id(), author.id());

        assertPhotoUnavailable(() -> uploadPhotoUseCase.uploadPhoto(command(
                participant.id(),
                memory.id(),
                MEDIA_ID
        )));

        assertThat(memoryRepository.findById(memory.id())).contains(memory);
        assertNoProcessingStorageOrMetadata();
    }

    private void assertDeniedAuthorRoleKeepsSystemUnchanged(StoryRole role) {
        User owner = saveUser(OWNER_ID, "owner-google-subject");
        User author = saveUser(USER_ID, "author-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(story.id(), author.id(), role);
        Memory memory = saveMemory(MEMORY_ID, story.id(), author.id());

        assertPhotoUnavailable(() -> uploadPhotoUseCase.uploadPhoto(command(
                author.id(),
                memory.id(),
                MEDIA_ID
        )));

        assertThat(memoryRepository.findById(memory.id())).contains(memory);
        assertNoProcessingStorageOrMetadata();
    }

    private void assertNoProcessingStorageOrMetadata() {
        assertThat(imageProcessor.inputs).isEmpty();
        assertThat(storageService.objects).isEmpty();
        assertThat(storageService.deletedKeys).isEmpty();
        assertThat(mediaFileRepository.findById(MEDIA_ID)).isEmpty();
        assertThat(mediaFileRepository.findById(SECOND_MEDIA_ID)).isEmpty();
    }

    private void assertStoredObject(StorageKey key, byte[] expectedContent) {
        StorageObjectWrite object = storageService.objects.get(key);

        assertThat(object.storageKey()).isEqualTo(key);
        assertThat(object.content()).containsExactly(expectedContent);
        assertThat(object.contentLength()).isEqualTo(expectedContent.length);
        assertThat(object.contentType()).isEqualTo("image/jpeg");
    }

    private User saveUser(UUID id, String googleSubject) {
        return userRepository.save(new User(
                id,
                googleSubject,
                "Memory Map User",
                null,
                BASE_TIME,
                BASE_TIME
        ));
    }

    private Story saveStory(UUID id, UUID ownerId) {
        return storyRepository.save(new Story(
                id,
                ownerId,
                "Our Story",
                "The beginning",
                null,
                BASE_TIME,
                BASE_TIME
        ));
    }

    private void saveParticipant(
            UUID storyId,
            UUID userId,
            StoryRole role
    ) {
        storyParticipantRepository.save(new StoryParticipant(
                storyId,
                userId,
                role,
                BASE_TIME
        ));
    }

    private Memory saveMemory(UUID id, UUID storyId, UUID createdBy) {
        Memory memory = new Memory(
                id,
                storyId,
                createdBy,
                "First trip",
                "A spring walk",
                "Tbilisi",
                41.715137,
                44.827096,
                EVENT_DATE,
                BASE_TIME,
                BASE_TIME
        );
        memoryRepository.save(memory);

        return memory;
    }

    private static UploadPhotoCommand command(
            UUID userId,
            UUID memoryId,
            UUID mediaId
    ) {
        return new UploadPhotoCommand(
                new AuthenticatedUser(userId),
                memoryId,
                mediaId,
                IMAGE,
                CURRENT_TIME
        );
    }

    private static MediaFile expectedMediaFile(UUID mediaId, UUID memoryId) {
        return new MediaFile(
                mediaId,
                memoryId,
                MediaType.PHOTO,
                displayKey(mediaId).value(),
                DISPLAY_BYTES.length,
                thumbnailKey(mediaId).value(),
                THUMBNAIL_BYTES.length,
                "image/jpeg",
                CURRENT_TIME
        );
    }

    private static StorageKey displayKey(UUID mediaId) {
        return new StorageKey("media/" + mediaId + "/display");
    }

    private static StorageKey thumbnailKey(UUID mediaId) {
        return new StorageKey("media/" + mediaId + "/thumbnail");
    }

    private static void assertPhotoUnavailable(ThrowingAction action) {
        assertThatThrownBy(action::run)
                .isInstanceOf(PhotoUploadUnavailableException.class)
                .hasMessage("Photo could not be uploaded");
    }

    private static PhotoUploadUnavailableException catchPhotoUnavailable(
            ThrowingAction action
    ) {
        try {
            action.run();
        } catch (PhotoUploadUnavailableException exception) {
            return exception;
        }

        throw new AssertionError("Expected PhotoUploadUnavailableException");
    }

    private interface ThrowingAction {

        void run();
    }

    @TestConfiguration(proxyBeanMethods = false)
    static class UploadPhotoUseCaseTestConfiguration {

        @Bean
        @Primary
        UploadPhotoUseCase testUploadPhotoUseCase(
                MemoryRepository memoryRepository,
                StoryParticipantRepository storyParticipantRepository,
                MediaFileRepository mediaFileRepository,
                PhotoUploadAuthorizationPolicy authorizationPolicy,
                ImageProcessor imageProcessor,
                MediaStorageKeyFactory storageKeyFactory,
                StorageService storageService,
                TransactionRollbackCoordinator rollbackCoordinator,
                NotificationPublisher notificationPublisher
        ) {
            return new CoordinatedUploadPhotoService(
                    memoryRepository,
                    storyParticipantRepository,
                    mediaFileRepository,
                    authorizationPolicy,
                    imageProcessor,
                    storageKeyFactory,
                    storageService,
                    rollbackCoordinator,
                    notificationPublisher
            );
        }

        @Bean
        @Primary
        TestMediaFileRepository testMediaFileRepository(
                JdbcMediaFileRepository delegate
        ) {
            return new TestMediaFileRepository(delegate);
        }

        @Bean
        @Primary
        TestImageProcessor testImageProcessor() {
            return new TestImageProcessor();
        }

        @Bean
        @Primary
        TestStorageService testStorageService() {
            return new TestStorageService();
        }
    }

    static final class TestMediaFileRepository
            implements MediaFileRepository {

        private final MediaFileRepository delegate;
        private RuntimeException failureAfterSave;

        private TestMediaFileRepository(MediaFileRepository delegate) {
            this.delegate = delegate;
        }

        @Override
        public Optional<MediaFile> findById(UUID id) {
            return delegate.findById(id);
        }

        @Override
        public List<MediaFile> findByMemoryId(UUID memoryId) {
            return delegate.findByMemoryId(memoryId);
        }

        @Override
        public void save(MediaFile mediaFile) {
            delegate.save(mediaFile);

            if (failureAfterSave != null) {
                throw failureAfterSave;
            }
        }

        @Override
        public void delete(UUID id) {
            delegate.delete(id);
        }

        private void failAfterSave(RuntimeException failure) {
            failureAfterSave = failure;
        }

        private void reset() {
            failureAfterSave = null;
        }
    }

    static final class TestImageProcessor implements ImageProcessor {

        private final List<ImageProcessingInput> inputs = new ArrayList<>();
        private RuntimeException failure;

        @Override
        public ProcessedPhoto process(ImageProcessingInput input) {
            inputs.add(input);

            if (failure != null) {
                throw failure;
            }

            return new ProcessedPhoto(
                    new ProcessedImage(DISPLAY_BYTES),
                    new ProcessedImage(THUMBNAIL_BYTES),
                    "image/jpeg"
            );
        }

        private void reset() {
            inputs.clear();
            failure = null;
        }
    }

    static final class TestStorageService implements StorageService {

        private final Map<StorageKey, StorageObjectWrite> objects =
                new LinkedHashMap<>();
        private final List<StorageKey> deletedKeys = new ArrayList<>();
        private final Map<StorageKey, RuntimeException> storeFailures =
                new LinkedHashMap<>();

        @Override
        public void store(StorageObjectWrite object) {
            RuntimeException failure = storeFailures.get(object.storageKey());

            if (failure != null) {
                throw failure;
            }

            objects.put(object.storageKey(), object);
        }

        @Override
        public StoredObject read(StorageKey storageKey) {
            StorageObjectWrite object = objects.get(storageKey);

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
            deletedKeys.add(storageKey);
            objects.remove(storageKey);
        }

        private void failStoreFor(
                StorageKey storageKey,
                RuntimeException failure
        ) {
            storeFailures.put(storageKey, failure);
        }

        private void reset() {
            objects.clear();
            deletedKeys.clear();
            storeFailures.clear();
        }
    }
}
