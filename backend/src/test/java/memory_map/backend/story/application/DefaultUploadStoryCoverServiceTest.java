package memory_map.backend.story.application;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.media.application.TransactionCommitCoordinator;
import memory_map.backend.media.application.TransactionRollbackCoordinator;
import memory_map.backend.media.image.ImageProcessingException;
import memory_map.backend.media.image.ImageProcessingInput;
import memory_map.backend.media.image.ImageProcessor;
import memory_map.backend.media.image.InvalidImageException;
import memory_map.backend.media.image.InvalidImageReason;
import memory_map.backend.media.image.ProcessedImage;
import memory_map.backend.media.image.ProcessedPhoto;
import memory_map.backend.media.storage.StorageByteRange;
import memory_map.backend.media.storage.StorageKey;
import memory_map.backend.media.storage.StorageObjectWrite;
import memory_map.backend.media.storage.StorageService;
import memory_map.backend.media.storage.StoredObject;
import memory_map.backend.story.domain.Story;
import memory_map.backend.story.domain.StoryCoverMetadata;
import memory_map.backend.story.repository.StoryRepository;
import memory_map.backend.story.repository.UserStoryRepository;
import memory_map.backend.storyparticipant.domain.StoryParticipant;
import memory_map.backend.storyparticipant.domain.StoryRole;
import memory_map.backend.storyparticipant.repository.StoryParticipantRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;

import java.io.ByteArrayInputStream;
import java.time.Instant;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class DefaultUploadStoryCoverServiceTest {

    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID OWNER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000002");
    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000011");
    private static final UUID COVER_OBJECT_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000031");
    private static final Instant CREATED_AT =
            Instant.parse("2026-01-01T10:00:00Z");
    private static final Instant UPDATED_AT =
            Instant.parse("2026-01-02T10:00:00Z");
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
    private final FakeStoryRepository storyRepository =
            new FakeStoryRepository(events);
    private final FakeStoryParticipantRepository storyParticipantRepository =
            new FakeStoryParticipantRepository(events);
    private final FakeUserStoryRepository userStoryRepository =
            new FakeUserStoryRepository(events);
    private final FakeImageProcessor imageProcessor =
            new FakeImageProcessor(events);
    private final StoryCoverStorageKeyFactory storageKeyFactory =
            new DeterministicStoryCoverStorageKeyFactory();
    private final FakeStorageService storageService =
            new FakeStorageService(events);
    private final FakeRollbackCoordinator rollbackCoordinator =
            new FakeRollbackCoordinator(events);
    private final FakeCommitCoordinator commitCoordinator =
            new FakeCommitCoordinator(events);
    private final DefaultUploadStoryCoverService service =
            new DefaultUploadStoryCoverService(
                    storyRepository,
                    storyParticipantRepository,
                    userStoryRepository,
                    imageProcessor,
                    storageKeyFactory,
                    storageService,
                    rollbackCoordinator,
                    commitCoordinator
            );

    @Test
    void shouldUploadFirstCoverForOwnerAndReturnAuthoritativeStory() {
        storyRepository.story = Optional.of(story(null));
        storyParticipantRepository.participant =
                Optional.of(participant(StoryRole.OWNER));

        UserStory result = service.uploadStoryCover(command());

        assertThat(result).isSameAs(userStoryRepository.userStory);
        assertThat(storyRepository.requestedLockId).isEqualTo(STORY_ID);
        assertThat(storyRepository.updatedCover)
                .isEqualTo(expectedNewCover());
        assertThat(storyRepository.updatedCover.displayStorageKey())
                .startsWith("stories/%s/cover/".formatted(STORY_ID))
                .endsWith("/display");
        assertThat(storyRepository.updatedCover.thumbnailStorageKey())
                .startsWith("stories/%s/cover/".formatted(STORY_ID))
                .endsWith("/thumbnail");
        assertThat(storyRepository.updatedCover.displayStorageKey())
                .isNotEqualTo(
                        storyRepository.updatedCover.thumbnailStorageKey()
                );
        assertThat(storyRepository.updatedCover.displayFileSize())
                .isEqualTo(DISPLAY_BYTES.length);
        assertThat(storyRepository.updatedCover.thumbnailFileSize())
                .isEqualTo(THUMBNAIL_BYTES.length);
        assertThat(storyRepository.updatedCover.mimeType())
                .isEqualTo("image/jpeg");
        assertThat(storyRepository.updatedCover.updatedAt())
                .isEqualTo(CURRENT_TIME);
        assertStoredObject(displayKey(), DISPLAY_BYTES);
        assertStoredObject(thumbnailKey(), THUMBNAIL_BYTES);
        assertThat(rollbackCoordinator.actions).hasSize(1);
        assertThat(commitCoordinator.actions).isEmpty();
        assertThat(storageService.deletedKeys).isEmpty();
        assertThat(events).containsExactly(
                "story.findByIdForUpdate",
                "participant.find",
                "image.process",
                "storage.store:display",
                "storage.store:thumbnail",
                "rollback.register",
                "story.updateCover",
                "userStory.findByStoryIdAndUserId"
        );
    }

    @Test
    void shouldReplaceCoverForCoOwnerAndCleanupOldAfterCommit() {
        storyRepository.story = Optional.of(story(oldCover()));
        storyParticipantRepository.participant =
                Optional.of(participant(StoryRole.CO_OWNER));

        UserStory result = service.uploadStoryCover(command());

        assertThat(result).isSameAs(userStoryRepository.userStory);
        assertThat(storyRepository.updatedCover).isEqualTo(expectedNewCover());
        assertThat(storageService.deletedKeys).isEmpty();
        assertThat(commitCoordinator.actions).hasSize(1);

        commitCoordinator.runFirstAction();

        assertThat(storageService.deletedKeys).containsExactly(
                new StorageKey("stories/story/old/thumbnail"),
                new StorageKey("stories/story/old/display")
        );
    }

    @Test
    void shouldAdvanceCoverVersionWhenReplacementClockDoesNotMoveForward() {
        Instant oldUpdatedAt = Instant.parse("2026-01-10T10:00:00.123Z");
        Instant staleCurrentTime = Instant.parse("2026-01-10T10:00:00.122Z");
        storyRepository.story = Optional.of(story(oldCover(oldUpdatedAt)));
        storyParticipantRepository.participant =
                Optional.of(participant(StoryRole.OWNER));

        service.uploadStoryCover(command(staleCurrentTime));

        assertThat(storyRepository.updatedCover.updatedAt())
                .isEqualTo(Instant.ofEpochMilli(
                        oldUpdatedAt.toEpochMilli() + 1
                ));
        assertThat(storyRepository.updatedCover.updatedAt().toEpochMilli())
                .isGreaterThan(oldUpdatedAt.toEpochMilli());
    }

    @ParameterizedTest
    @EnumSource(value = StoryRole.class, names = {"EDITOR", "VIEWER"})
    void shouldDenyRolesThatCannotUploadCoverBeforeProcessing(StoryRole role) {
        storyParticipantRepository.participant =
                Optional.of(participant(role));

        assertThatThrownBy(() -> service.uploadStoryCover(command()))
                .isInstanceOf(StoryNotFoundException.class)
                .hasMessage("Story was not found");

        assertNoProcessingStorageOrPersistence();
        assertThat(events).containsExactly(
                "story.findByIdForUpdate",
                "participant.find"
        );
    }

    @Test
    void shouldConcealMissingStoryBeforeMembershipLookup() {
        storyRepository.story = Optional.empty();

        assertThatThrownBy(() -> service.uploadStoryCover(command()))
                .isInstanceOf(StoryNotFoundException.class)
                .hasMessage("Story was not found");

        assertThat(events).containsExactly("story.findByIdForUpdate");
        assertThat(storyParticipantRepository.callCount).isZero();
        assertNoProcessingStorageOrPersistence();
    }

    @Test
    void shouldConcealNonParticipantBeforeProcessing() {
        storyParticipantRepository.participant = Optional.empty();

        assertThatThrownBy(() -> service.uploadStoryCover(command()))
                .isInstanceOf(StoryNotFoundException.class)
                .hasMessage("Story was not found");

        assertThat(events).containsExactly(
                "story.findByIdForUpdate",
                "participant.find"
        );
        assertNoProcessingStorageOrPersistence();
    }

    @Test
    void shouldPropagateInvalidImageBeforeStorage() {
        InvalidImageException failure = new InvalidImageException(
                InvalidImageReason.INVALID_IMAGE
        );
        imageProcessor.failure = failure;

        assertThatThrownBy(() -> service.uploadStoryCover(command()))
                .isSameAs(failure);

        assertThat(storageService.storedObjects).isEmpty();
        assertThat(storyRepository.updatedCover).isNull();
        assertThat(events).containsExactly(
                "story.findByIdForUpdate",
                "participant.find",
                "image.process"
        );
    }

    @Test
    void shouldPropagateImageProcessingFailureBeforeStorage() {
        ImageProcessingException failure = new ImageProcessingException();
        imageProcessor.failure = failure;

        assertThatThrownBy(() -> service.uploadStoryCover(command()))
                .isSameAs(failure);

        assertThat(storageService.storedObjects).isEmpty();
        assertThat(storyRepository.updatedCover).isNull();
    }

    @Test
    void shouldPropagateDisplayStoreFailureWithoutThumbnailOrDbUpdate() {
        RuntimeException failure = new RuntimeException("display failed");
        storageService.storeFailures.put(displayKey(), failure);

        assertThatThrownBy(() -> service.uploadStoryCover(command()))
                .isSameAs(failure);

        assertThat(storageService.storedObjects).isEmpty();
        assertThat(storageService.deletedKeys).isEmpty();
        assertThat(storyRepository.updatedCover).isNull();
        assertThat(events).containsExactly(
                "story.findByIdForUpdate",
                "participant.find",
                "image.process",
                "storage.store:display"
        );
    }

    @Test
    void shouldCleanupDisplayWhenThumbnailStoreFails() {
        RuntimeException failure = new RuntimeException("thumbnail failed");
        storageService.storeFailures.put(thumbnailKey(), failure);

        assertThatThrownBy(() -> service.uploadStoryCover(command()))
                .isSameAs(failure);

        assertThat(storageService.deletedKeys).containsExactly(displayKey());
        assertThat(storyRepository.updatedCover).isNull();
        assertThat(events).containsExactly(
                "story.findByIdForUpdate",
                "participant.find",
                "image.process",
                "storage.store:display",
                "storage.store:thumbnail",
                "storage.delete:display"
        );
    }

    @Test
    void shouldRegisterRollbackCleanupForBothNewObjectsBeforePersistence() {
        service.uploadStoryCover(command());

        rollbackCoordinator.runFirstAction();

        assertThat(storageService.deletedKeys).containsExactly(
                thumbnailKey(),
                displayKey()
        );
        assertThat(events).containsExactly(
                "story.findByIdForUpdate",
                "participant.find",
                "image.process",
                "storage.store:display",
                "storage.store:thumbnail",
                "rollback.register",
                "story.updateCover",
                "userStory.findByStoryIdAndUserId",
                "storage.delete:thumbnail",
                "storage.delete:display"
        );
    }

    @Test
    void shouldCleanupBothObjectsWhenRollbackRegistrationFails() {
        RuntimeException failure = new RuntimeException(
                "rollback registration failed"
        );
        rollbackCoordinator.failure = failure;

        assertThatThrownBy(() -> service.uploadStoryCover(command()))
                .isSameAs(failure);

        assertThat(storageService.deletedKeys).containsExactly(
                thumbnailKey(),
                displayKey()
        );
        assertThat(storyRepository.updatedCover).isNull();
    }

    @Test
    void shouldCleanupNewObjectsWhenCoverPersistenceFails() {
        RuntimeException failure = new RuntimeException("db failed");
        storyRepository.updateFailure = failure;

        assertThatThrownBy(() -> service.uploadStoryCover(command()))
                .isSameAs(failure);

        assertThat(rollbackCoordinator.actions).hasSize(1);
        assertThat(storageService.deletedKeys).containsExactly(
                thumbnailKey(),
                displayKey()
        );
        assertThat(commitCoordinator.actions).isEmpty();
        assertThat(userStoryRepository.callCount).isZero();
    }

    @Test
    void shouldCleanupNewObjectsWhenAuthoritativeProjectionFails() {
        RuntimeException failure = new RuntimeException("projection failed");
        userStoryRepository.failure = failure;

        assertThatThrownBy(() -> service.uploadStoryCover(command()))
                .isSameAs(failure);

        assertThat(storageService.deletedKeys).containsExactly(
                thumbnailKey(),
                displayKey()
        );
        assertThat(commitCoordinator.actions).isEmpty();
    }

    @Test
    void shouldPropagateStoryNotFoundWhenAuthoritativeProjectionIsMissing() {
        userStoryRepository.userStory = null;

        assertThatThrownBy(() -> service.uploadStoryCover(command()))
                .isInstanceOf(StoryNotFoundException.class)
                .hasMessage("Story was not found");

        assertThat(storageService.deletedKeys).containsExactly(
                thumbnailKey(),
                displayKey()
        );
    }

    @Test
    void shouldCleanupNewObjectsIfOldCleanupRegistrationFails() {
        storyRepository.story = Optional.of(story(oldCover()));
        RuntimeException failure = new RuntimeException(
                "commit registration failed"
        );
        commitCoordinator.failure = failure;

        assertThatThrownBy(() -> service.uploadStoryCover(command()))
                .isSameAs(failure);

        assertThat(storageService.deletedKeys).containsExactly(
                thumbnailKey(),
                displayKey()
        );
    }

    @Test
    void shouldSuppressCleanupFailuresWhenPersistenceFails() {
        RuntimeException persistenceFailure = new RuntimeException("db failed");
        RuntimeException thumbnailCleanupFailure = new RuntimeException(
                "thumbnail cleanup failed"
        );
        RuntimeException displayCleanupFailure = new RuntimeException(
                "display cleanup failed"
        );
        storyRepository.updateFailure = persistenceFailure;
        storageService.deleteFailures.put(
                thumbnailKey(),
                thumbnailCleanupFailure
        );
        storageService.deleteFailures.put(displayKey(), displayCleanupFailure);

        assertThatThrownBy(() -> service.uploadStoryCover(command()))
                .isSameAs(persistenceFailure)
                .satisfies(exception -> assertThat(
                        exception.getSuppressed()
                ).containsExactly(
                        thumbnailCleanupFailure,
                        displayCleanupFailure
                ));
    }

    @Test
    void shouldGenerateStoryOwnedStorageKeys() {
        StoryCoverStorageKeys keys = storageKeyFactory.keysFor(
                STORY_ID,
                COVER_OBJECT_ID
        );

        assertThat(keys.display().value())
                .isEqualTo("stories/%s/cover/%s/display".formatted(
                        STORY_ID,
                        COVER_OBJECT_ID
                ));
        assertThat(keys.thumbnail().value())
                .isEqualTo("stories/%s/cover/%s/thumbnail".formatted(
                        STORY_ID,
                        COVER_OBJECT_ID
                ));
        assertThat(keys.display()).isNotEqualTo(keys.thumbnail());
    }

    @Test
    void shouldRejectNullDependenciesAndCommand() {
        assertThatThrownBy(() -> new DefaultUploadStoryCoverService(
                null,
                storyParticipantRepository,
                userStoryRepository,
                imageProcessor,
                storageKeyFactory,
                storageService,
                rollbackCoordinator,
                commitCoordinator
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("storyRepository must not be null");
        assertThatThrownBy(() -> new DefaultUploadStoryCoverService(
                storyRepository,
                null,
                userStoryRepository,
                imageProcessor,
                storageKeyFactory,
                storageService,
                rollbackCoordinator,
                commitCoordinator
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("storyParticipantRepository must not be null");
        assertThatThrownBy(() -> new DefaultUploadStoryCoverService(
                storyRepository,
                storyParticipantRepository,
                null,
                imageProcessor,
                storageKeyFactory,
                storageService,
                rollbackCoordinator,
                commitCoordinator
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("userStoryRepository must not be null");
        assertThatThrownBy(() -> new DefaultUploadStoryCoverService(
                storyRepository,
                storyParticipantRepository,
                userStoryRepository,
                null,
                storageKeyFactory,
                storageService,
                rollbackCoordinator,
                commitCoordinator
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("imageProcessor must not be null");
        assertThatThrownBy(() -> new DefaultUploadStoryCoverService(
                storyRepository,
                storyParticipantRepository,
                userStoryRepository,
                imageProcessor,
                null,
                storageService,
                rollbackCoordinator,
                commitCoordinator
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("storageKeyFactory must not be null");
        assertThatThrownBy(() -> new DefaultUploadStoryCoverService(
                storyRepository,
                storyParticipantRepository,
                userStoryRepository,
                imageProcessor,
                storageKeyFactory,
                null,
                rollbackCoordinator,
                commitCoordinator
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("storageService must not be null");
        assertThatThrownBy(() -> new DefaultUploadStoryCoverService(
                storyRepository,
                storyParticipantRepository,
                userStoryRepository,
                imageProcessor,
                storageKeyFactory,
                storageService,
                null,
                commitCoordinator
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("rollbackCoordinator must not be null");
        assertThatThrownBy(() -> new DefaultUploadStoryCoverService(
                storyRepository,
                storyParticipantRepository,
                userStoryRepository,
                imageProcessor,
                storageKeyFactory,
                storageService,
                rollbackCoordinator,
                null
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("commitCoordinator must not be null");
        assertThatThrownBy(() -> service.uploadStoryCover(null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("command must not be null");
    }

    private void assertNoProcessingStorageOrPersistence() {
        assertThat(imageProcessor.processedInputs).isEmpty();
        assertThat(storageService.storedObjects).isEmpty();
        assertThat(storyRepository.updatedCover).isNull();
        assertThat(userStoryRepository.callCount).isZero();
        assertThat(rollbackCoordinator.actions).isEmpty();
        assertThat(commitCoordinator.actions).isEmpty();
    }

    private void assertStoredObject(StorageKey key, byte[] expectedContent) {
        StorageObjectWrite object = storageService.storedObjects.get(key);

        assertThat(object.storageKey()).isEqualTo(key);
        assertThat(object.content()).containsExactly(expectedContent);
        assertThat(object.contentLength()).isEqualTo(expectedContent.length);
        assertThat(object.contentType()).isEqualTo("image/jpeg");
    }

    private static UploadStoryCoverCommand command() {
        return command(CURRENT_TIME);
    }

    private static UploadStoryCoverCommand command(Instant currentTime) {
        return new UploadStoryCoverCommand(
                new AuthenticatedUser(USER_ID),
                STORY_ID,
                COVER_OBJECT_ID,
                IMAGE,
                currentTime
        );
    }

    private static Story story(StoryCoverMetadata cover) {
        return new Story(
                STORY_ID,
                OWNER_ID,
                "Our Story",
                "The beginning",
                null,
                cover,
                CREATED_AT,
                UPDATED_AT
        );
    }

    private static StoryParticipant participant(StoryRole role) {
        return new StoryParticipant(STORY_ID, USER_ID, role, CREATED_AT);
    }

    private static StoryCoverMetadata oldCover() {
        return oldCover(UPDATED_AT);
    }

    private static StoryCoverMetadata oldCover(Instant updatedAt) {
        return new StoryCoverMetadata(
                "stories/story/old/display",
                2_048L,
                "stories/story/old/thumbnail",
                360L,
                "image/jpeg",
                updatedAt
        );
    }

    private static StoryCoverMetadata expectedNewCover() {
        return new StoryCoverMetadata(
                displayKey().value(),
                DISPLAY_BYTES.length,
                thumbnailKey().value(),
                THUMBNAIL_BYTES.length,
                "image/jpeg",
                CURRENT_TIME
        );
    }

    private static StorageKey displayKey() {
        return new StorageKey(
                "stories/%s/cover/%s/display".formatted(
                        STORY_ID,
                        COVER_OBJECT_ID
                )
        );
    }

    private static StorageKey thumbnailKey() {
        return new StorageKey(
                "stories/%s/cover/%s/thumbnail".formatted(
                        STORY_ID,
                        COVER_OBJECT_ID
                )
        );
    }

    private static final class FakeStoryRepository
            implements StoryRepository {

        private final List<String> events;
        private Optional<Story> story = Optional.of(story(null));
        private UUID requestedLockId;
        private StoryCoverMetadata updatedCover;
        private RuntimeException updateFailure;

        private FakeStoryRepository(List<String> events) {
            this.events = events;
        }

        @Override
        public Story save(Story story) {
            throw new UnsupportedOperationException();
        }

        @Override
        public Story update(Story story) {
            throw new UnsupportedOperationException();
        }

        @Override
        public Optional<Story> findById(UUID id) {
            throw new UnsupportedOperationException();
        }

        @Override
        public Optional<Story> findByIdForUpdate(UUID id) {
            events.add("story.findByIdForUpdate");
            requestedLockId = id;
            return story;
        }

        @Override
        public boolean lockById(UUID id) {
            throw new UnsupportedOperationException();
        }

        @Override
        public Story updateCover(UUID id, StoryCoverMetadata cover) {
            events.add("story.updateCover");

            if (updateFailure != null) {
                throw updateFailure;
            }

            updatedCover = cover;
            return story(cover);
        }

        @Override
        public List<Story> findByOwnerId(UUID ownerId) {
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

    private static final class FakeUserStoryRepository
            implements UserStoryRepository {

        private final List<String> events;
        private UserStory userStory = new UserStory(
                story(null),
                StoryRole.OWNER,
                3,
                2,
                new StoryPhotoPreview(
                        "/api/v1/stories/%s/cover/thumbnail/%d".formatted(
                                STORY_ID,
                                CURRENT_TIME.toEpochMilli()
                        ),
                        "/api/v1/stories/%s/cover/display/%d".formatted(
                                STORY_ID,
                                CURRENT_TIME.toEpochMilli()
                        )
                )
        );
        private RuntimeException failure;
        private int callCount;

        private FakeUserStoryRepository(List<String> events) {
            this.events = events;
        }

        @Override
        public List<UserStory> findByUserId(UUID userId) {
            throw new UnsupportedOperationException();
        }

        @Override
        public Optional<UserStory> findByStoryIdAndUserId(
                UUID storyId,
                UUID userId
        ) {
            events.add("userStory.findByStoryIdAndUserId");
            callCount++;

            if (failure != null) {
                throw failure;
            }

            return Optional.ofNullable(userStory);
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

            if (Objects.equals(
                    key,
                    new StorageKey("stories/story/old/display")
            )) {
                return "old-display";
            }

            if (Objects.equals(
                    key,
                    new StorageKey("stories/story/old/thumbnail")
            )) {
                return "old-thumbnail";
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

    private static final class FakeCommitCoordinator
            implements TransactionCommitCoordinator {

        private final List<String> events;
        private final List<Runnable> actions = new ArrayList<>();
        private RuntimeException failure;

        private FakeCommitCoordinator(List<String> events) {
            this.events = events;
        }

        @Override
        public void onCommit(Runnable action) {
            events.add("commit.register");

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
