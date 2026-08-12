package memory_map.backend.media.application;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.media.domain.MediaFile;
import memory_map.backend.media.domain.MediaType;
import memory_map.backend.media.repository.MediaFileRepository;
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

import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Objects;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class TransactionalDeleteMediaServiceTest {

    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID OWNER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000002");
    private static final UUID AUTHOR_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000003");
    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000011");
    private static final UUID OTHER_STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000012");
    private static final UUID MEMORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000021");
    private static final UUID MEDIA_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000031");
    private static final Instant BASE_TIME =
            Instant.parse("2026-01-01T10:00:00Z");

    private final List<String> events = new ArrayList<>();
    private final FakeMediaFileRepository mediaFileRepository =
            new FakeMediaFileRepository(events);
    private final FakeMemoryRepository memoryRepository =
            new FakeMemoryRepository(events);
    private final FakeStoryParticipantRepository storyParticipantRepository =
            new FakeStoryParticipantRepository(events);
    private final DeleteMediaAuthorizationPolicy authorizationPolicy =
            new DeleteMediaAuthorizationPolicy();
    private final FakeStorageService storageService =
            new FakeStorageService(events);
    private final FakeCommitCoordinator commitCoordinator =
            new FakeCommitCoordinator(events);
    private final TransactionalDeleteMediaService service =
            new TransactionalDeleteMediaService(
                    mediaFileRepository,
                    memoryRepository,
                    storyParticipantRepository,
                    authorizationPolicy,
                    storageService,
                    commitCoordinator
            );

    @Test
    void shouldDeleteMediaForOwnerAndCleanupStorageAfterCommit() {
        arrangeCurrentMemory(AUTHOR_ID);
        arrangeCurrentParticipant(USER_ID, StoryRole.OWNER);

        service.deleteMedia(command(USER_ID));

        assertThat(mediaFileRepository.requestedId).isEqualTo(MEDIA_ID);
        assertThat(memoryRepository.requestedId).isEqualTo(MEMORY_ID);
        assertThat(storyParticipantRepository.requestedStoryId)
                .isEqualTo(STORY_ID);
        assertThat(storyParticipantRepository.requestedUserId)
                .isEqualTo(USER_ID);
        assertThat(mediaFileRepository.deletedId).isEqualTo(MEDIA_ID);
        assertThat(storageService.deletedKeys).isEmpty();
        assertThat(commitCoordinator.actions).hasSize(1);
        assertThat(events).containsExactly(
                "media.findById",
                "memory.findByIdForUpdate",
                "participant.find",
                "media.delete",
                "commit.register"
        );

        commitCoordinator.runFirstAction();

        assertThat(storageService.deletedKeys).containsExactly(
                thumbnailKey(),
                displayKey()
        );
        assertThat(events).containsExactly(
                "media.findById",
                "memory.findByIdForUpdate",
                "participant.find",
                "media.delete",
                "commit.register",
                "storage.delete:thumbnail",
                "storage.delete:display"
        );
    }

    @Test
    void shouldDeleteMediaForCoOwner() {
        arrangeCurrentMemory(AUTHOR_ID);
        arrangeCurrentParticipant(USER_ID, StoryRole.CO_OWNER);

        service.deleteMedia(command(USER_ID));

        assertThat(mediaFileRepository.deletedId).isEqualTo(MEDIA_ID);
        commitCoordinator.runFirstAction();
        assertThat(storageService.deletedKeys).containsExactly(
                thumbnailKey(),
                displayKey()
        );
    }

    @Test
    void shouldDeleteOwnMemoryMediaForEditorAndViewer() {
        assertAuthorRoleCanDeleteOwnMedia(StoryRole.EDITOR);
        reset();
        assertAuthorRoleCanDeleteOwnMedia(StoryRole.VIEWER);
    }

    @Test
    void shouldDenyEditorAndViewerForAnotherAuthorsMemory() {
        assertDeniedRoleLeavesMetadataAndStorageUntouched(StoryRole.EDITOR);
        reset();
        assertDeniedRoleLeavesMetadataAndStorageUntouched(StoryRole.VIEWER);
    }

    @Test
    void shouldThrowUnavailableWhenMediaIsMissingBeforeAnyOtherWork() {
        mediaFileRepository.mediaFile = Optional.empty();

        assertUnavailable(() -> service.deleteMedia(command(USER_ID)));

        assertNoMetadataDeleteOrStorageWork();
        assertThat(events).containsExactly("media.findById");
    }

    @Test
    void shouldThrowUnavailableWhenParentMemoryIsMissing() {
        memoryRepository.memory = Optional.empty();

        assertUnavailable(() -> service.deleteMedia(command(USER_ID)));

        assertNoMetadataDeleteOrStorageWork();
        assertThat(events).containsExactly(
                "media.findById",
                "memory.findByIdForUpdate"
        );
    }

    @Test
    void shouldThrowUnavailableWhenMembershipIsMissing() {
        arrangeCurrentMemory(AUTHOR_ID);
        storyParticipantRepository.participant = Optional.empty();

        assertUnavailable(() -> service.deleteMedia(command(USER_ID)));

        assertNoMetadataDeleteOrStorageWork();
        assertThat(events).containsExactly(
                "media.findById",
                "memory.findByIdForUpdate",
                "participant.find"
        );
    }

    @Test
    void shouldDenyFormerAuthorWithoutMembership() {
        arrangeCurrentMemory(USER_ID);
        storyParticipantRepository.participant = Optional.empty();

        assertUnavailable(() -> service.deleteMedia(command(USER_ID)));

        assertNoMetadataDeleteOrStorageWork();
    }

    @Test
    void shouldDenyParticipantOfAnotherStory() {
        arrangeCurrentMemory(AUTHOR_ID);
        storyParticipantRepository.participant = Optional.of(
                new StoryParticipant(
                        OTHER_STORY_ID,
                        USER_ID,
                        StoryRole.OWNER,
                        BASE_TIME
                )
        );

        assertUnavailable(() -> service.deleteMedia(command(USER_ID)));

        assertNoMetadataDeleteOrStorageWork();
    }

    @Test
    void shouldUseTrustedPersistedStorageKeys() {
        mediaFileRepository.mediaFile = Optional.of(new MediaFile(
                MEDIA_ID,
                MEMORY_ID,
                MediaType.PHOTO,
                "trusted-display-key",
                1_024L,
                "trusted-thumbnail-key",
                128L,
                "image/jpeg",
                BASE_TIME
        ));
        arrangeCurrentMemory(AUTHOR_ID);
        arrangeCurrentParticipant(USER_ID, StoryRole.OWNER);

        service.deleteMedia(command(USER_ID));
        commitCoordinator.runFirstAction();

        assertThat(storageService.deletedKeys).containsExactly(
                new StorageKey("trusted-thumbnail-key"),
                new StorageKey("trusted-display-key")
        );
    }

    @Test
    void shouldNotCleanupStorageWhenCommitActionIsNotRun() {
        arrangeCurrentMemory(AUTHOR_ID);
        arrangeCurrentParticipant(USER_ID, StoryRole.OWNER);

        service.deleteMedia(command(USER_ID));

        assertThat(mediaFileRepository.deletedId).isEqualTo(MEDIA_ID);
        assertThat(storageService.deletedKeys).isEmpty();
    }

    @Test
    void shouldKeepMetadataDeletedWhenCleanupFailsAfterCommit() {
        arrangeCurrentMemory(AUTHOR_ID);
        arrangeCurrentParticipant(USER_ID, StoryRole.OWNER);
        storageService.failure = new RuntimeException("provider failed");

        service.deleteMedia(command(USER_ID));
        commitCoordinator.runFirstAction();

        assertThat(mediaFileRepository.deletedId).isEqualTo(MEDIA_ID);
        assertThat(storageService.deletedKeys).containsExactly(
                thumbnailKey(),
                displayKey()
        );
    }

    @Test
    void shouldPropagateLookupRepositoryFailureBeforeStorageWork() {
        RuntimeException failure = new RuntimeException("media lookup failed");
        mediaFileRepository.findFailure = failure;

        assertThatThrownBy(() -> service.deleteMedia(command(USER_ID)))
                .isSameAs(failure);

        assertNoMetadataDeleteOrStorageWork();
    }

    @Test
    void shouldPropagateMetadataDeleteFailureAndNotRegisterCleanup() {
        arrangeCurrentMemory(AUTHOR_ID);
        arrangeCurrentParticipant(USER_ID, StoryRole.OWNER);
        RuntimeException failure = new RuntimeException("db delete failed");
        mediaFileRepository.deleteFailure = failure;

        assertThatThrownBy(() -> service.deleteMedia(command(USER_ID)))
                .isSameAs(failure);

        assertThat(commitCoordinator.actions).isEmpty();
        assertThat(storageService.deletedKeys).isEmpty();
    }

    @Test
    void shouldPropagateCommitRegistrationFailureBeforeStorageCleanup() {
        arrangeCurrentMemory(AUTHOR_ID);
        arrangeCurrentParticipant(USER_ID, StoryRole.OWNER);
        RuntimeException failure = new RuntimeException(
                "commit registration failed"
        );
        commitCoordinator.failure = failure;

        assertThatThrownBy(() -> service.deleteMedia(command(USER_ID)))
                .isSameAs(failure);

        assertThat(mediaFileRepository.deletedId).isEqualTo(MEDIA_ID);
        assertThat(commitCoordinator.actions).isEmpty();
        assertThat(storageService.deletedKeys).isEmpty();
    }

    @Test
    void shouldRejectNullDependencies() {
        assertThatThrownBy(() -> new TransactionalDeleteMediaService(
                null,
                memoryRepository,
                storyParticipantRepository,
                authorizationPolicy,
                storageService,
                commitCoordinator
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("mediaFileRepository must not be null");

        assertThatThrownBy(() -> new TransactionalDeleteMediaService(
                mediaFileRepository,
                null,
                storyParticipantRepository,
                authorizationPolicy,
                storageService,
                commitCoordinator
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("memoryRepository must not be null");

        assertThatThrownBy(() -> new TransactionalDeleteMediaService(
                mediaFileRepository,
                memoryRepository,
                null,
                authorizationPolicy,
                storageService,
                commitCoordinator
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("storyParticipantRepository must not be null");

        assertThatThrownBy(() -> new TransactionalDeleteMediaService(
                mediaFileRepository,
                memoryRepository,
                storyParticipantRepository,
                null,
                storageService,
                commitCoordinator
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("authorizationPolicy must not be null");

        assertThatThrownBy(() -> new TransactionalDeleteMediaService(
                mediaFileRepository,
                memoryRepository,
                storyParticipantRepository,
                authorizationPolicy,
                null,
                commitCoordinator
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("storageService must not be null");

        assertThatThrownBy(() -> new TransactionalDeleteMediaService(
                mediaFileRepository,
                memoryRepository,
                storyParticipantRepository,
                authorizationPolicy,
                storageService,
                null
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("commitCoordinator must not be null");
    }

    @Test
    void shouldRejectNullCommandBeforeRepositoryCalls() {
        assertThatThrownBy(() -> service.deleteMedia(null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("command must not be null");

        assertThat(events).isEmpty();
    }

    private void assertAuthorRoleCanDeleteOwnMedia(StoryRole role) {
        arrangeCurrentMemory(USER_ID);
        arrangeCurrentParticipant(USER_ID, role);

        service.deleteMedia(command(USER_ID));

        assertThat(mediaFileRepository.deletedId).isEqualTo(MEDIA_ID);
    }

    private void assertDeniedRoleLeavesMetadataAndStorageUntouched(
            StoryRole role
    ) {
        arrangeCurrentMemory(AUTHOR_ID);
        arrangeCurrentParticipant(USER_ID, role);

        MediaDeletionUnavailableException denied = catchUnavailable(
                () -> service.deleteMedia(command(USER_ID))
        );
        mediaFileRepository.mediaFile = Optional.empty();
        events.clear();
        MediaDeletionUnavailableException missing = catchUnavailable(
                () -> service.deleteMedia(command(USER_ID))
        );

        assertThat(denied.getClass()).isEqualTo(missing.getClass());
        assertThat(denied.getMessage())
                .isEqualTo(missing.getMessage())
                .isEqualTo("Media could not be deleted");
        assertNoMetadataDeleteOrStorageWork();
    }

    private void arrangeCurrentMemory(UUID createdBy) {
        memoryRepository.memory = Optional.of(memory(createdBy));
    }

    private void arrangeCurrentParticipant(UUID userId, StoryRole role) {
        storyParticipantRepository.participant = Optional.of(
                new StoryParticipant(STORY_ID, userId, role, BASE_TIME)
        );
    }

    private void reset() {
        events.clear();
        mediaFileRepository.reset();
        memoryRepository.reset();
        storyParticipantRepository.reset();
        storageService.reset();
        commitCoordinator.reset();
    }

    private void assertNoMetadataDeleteOrStorageWork() {
        assertThat(mediaFileRepository.deletedId).isNull();
        assertThat(commitCoordinator.actions).isEmpty();
        assertThat(storageService.deletedKeys).isEmpty();
    }

    private static void assertUnavailable(ThrowingAction action) {
        assertThatThrownBy(action::run)
                .isInstanceOf(MediaDeletionUnavailableException.class)
                .hasMessage("Media could not be deleted");
    }

    private static MediaDeletionUnavailableException catchUnavailable(
            ThrowingAction action
    ) {
        try {
            action.run();
        } catch (MediaDeletionUnavailableException exception) {
            return exception;
        }

        throw new AssertionError("Expected MediaDeletionUnavailableException");
    }

    private static DeleteMediaCommand command(UUID userId) {
        return new DeleteMediaCommand(new AuthenticatedUser(userId), MEDIA_ID);
    }

    private static MediaFile mediaFile() {
        return new MediaFile(
                MEDIA_ID,
                MEMORY_ID,
                MediaType.PHOTO,
                displayKey().value(),
                1_024L,
                thumbnailKey().value(),
                128L,
                "image/jpeg",
                BASE_TIME
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
                LocalDate.of(2024, 5, 20),
                BASE_TIME,
                BASE_TIME
        );
    }

    private static StorageKey displayKey() {
        return new StorageKey("media/%s/display".formatted(MEDIA_ID));
    }

    private static StorageKey thumbnailKey() {
        return new StorageKey("media/%s/thumbnail".formatted(MEDIA_ID));
    }

    private static final class FakeMediaFileRepository
            implements MediaFileRepository {

        private final List<String> events;
        private Optional<MediaFile> mediaFile = Optional.of(mediaFile());
        private UUID requestedId;
        private UUID deletedId;
        private RuntimeException findFailure;
        private RuntimeException deleteFailure;

        private FakeMediaFileRepository(List<String> events) {
            this.events = events;
        }

        @Override
        public Optional<MediaFile> findById(UUID id) {
            events.add("media.findById");
            requestedId = id;

            if (findFailure != null) {
                throw findFailure;
            }

            return mediaFile;
        }

        @Override
        public List<MediaFile> findByMemoryId(UUID memoryId) {
            return List.of();
        }

        @Override
        public void save(MediaFile mediaFile) {
        }

        @Override
        public void delete(UUID id) {
            events.add("media.delete");

            if (deleteFailure != null) {
                throw deleteFailure;
            }

            deletedId = id;
        }

        private void reset() {
            mediaFile = Optional.of(mediaFile());
            requestedId = null;
            deletedId = null;
            findFailure = null;
            deleteFailure = null;
        }
    }

    private static final class FakeMemoryRepository
            implements MemoryRepository {

        private final List<String> events;
        private Optional<Memory> memory = Optional.of(memory(AUTHOR_ID));
        private UUID requestedId;

        private FakeMemoryRepository(List<String> events) {
            this.events = events;
        }

        @Override
        public Optional<Memory> findById(UUID id) {
            return Optional.empty();
        }

        @Override
        public Optional<Memory> findByIdForUpdate(UUID id) {
            events.add("memory.findByIdForUpdate");
            requestedId = id;
            return memory;
        }

        @Override
        public List<Memory> findByStoryId(UUID storyId) {
            return List.of();
        }

        @Override
        public void save(Memory memory) {
        }

        @Override
        public boolean update(Memory memory) {
            return false;
        }

        @Override
        public boolean delete(UUID id) {
            return false;
        }

        private void reset() {
            memory = Optional.of(memory(AUTHOR_ID));
            requestedId = null;
        }
    }

    private static final class FakeStoryParticipantRepository
            implements StoryParticipantRepository {

        private final List<String> events;
        private Optional<StoryParticipant> participant = Optional.of(
                new StoryParticipant(
                        STORY_ID,
                        USER_ID,
                        StoryRole.OWNER,
                        BASE_TIME
                )
        );
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
            return List.of();
        }

        @Override
        public List<StoryParticipant> findByUserId(UUID userId) {
            return List.of();
        }

        @Override
        public long countOwners(UUID storyId) {
            return 0;
        }

        @Override
        public boolean exists(UUID storyId, UUID userId) {
            return false;
        }

        @Override
        public void save(StoryParticipant participant) {
        }

        @Override
        public void update(StoryParticipant participant) {
        }

        @Override
        public void delete(UUID storyId, UUID userId) {
        }

        private void reset() {
            participant = Optional.of(new StoryParticipant(
                    STORY_ID,
                    USER_ID,
                    StoryRole.OWNER,
                    BASE_TIME
            ));
            requestedStoryId = null;
            requestedUserId = null;
        }
    }

    private static final class FakeStorageService implements StorageService {

        private final List<String> events;
        private final List<StorageKey> deletedKeys = new ArrayList<>();
        private RuntimeException failure;

        private FakeStorageService(List<String> events) {
            this.events = events;
        }

        @Override
        public void store(StorageObjectWrite object) {
        }

        @Override
        public StoredObject read(StorageKey storageKey) {
            throw new UnsupportedOperationException();
        }

        @Override
        public void delete(StorageKey storageKey) {
            deletedKeys.add(storageKey);

            if (Objects.equals(storageKey, thumbnailKey())) {
                events.add("storage.delete:thumbnail");
            } else if (Objects.equals(storageKey, displayKey())) {
                events.add("storage.delete:display");
            } else {
                events.add("storage.delete:trusted");
            }

            if (failure != null) {
                throw failure;
            }
        }

        private void reset() {
            deletedKeys.clear();
            failure = null;
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

        private void reset() {
            actions.clear();
            failure = null;
        }
    }

    @FunctionalInterface
    private interface ThrowingAction {

        void run();
    }
}
