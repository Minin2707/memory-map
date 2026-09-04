package memory_map.backend.media.application;

import memory_map.backend.IntegrationTest;
import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.media.domain.MediaFile;
import memory_map.backend.media.domain.MediaType;
import memory_map.backend.media.repository.MediaFileRepository;
import memory_map.backend.media.storage.StorageByteRange;
import memory_map.backend.media.storage.StorageKey;
import memory_map.backend.media.storage.StorageObjectWrite;
import memory_map.backend.media.storage.StorageService;
import memory_map.backend.media.storage.StoredObject;
import memory_map.backend.memory.domain.Memory;
import memory_map.backend.memory.repository.MemoryRepository;
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
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

@Import(DeleteMediaUseCaseIntegrationTest.DeleteMediaUseCaseTestConfiguration.class)
class DeleteMediaUseCaseIntegrationTest extends IntegrationTest {

    @Autowired
    private DeleteMediaUseCase deleteMediaUseCase;

    @Autowired
    private MediaFileRepository mediaFileRepository;

    @Autowired
    private MemoryRepository memoryRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private StoryRepository storyRepository;

    @Autowired
    private StoryParticipantRepository storyParticipantRepository;

    @Autowired
    private TestStorageService storageService;

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
    private static final UUID OTHER_MEDIA_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000032");
    private static final Instant BASE_TIME =
            Instant.parse("2026-01-01T10:00:00.123456Z");
    private static final LocalDate EVENT_DATE =
            LocalDate.of(2024, 5, 20);
    private static final String CLEAN_DATABASE_SQL = """
        TRUNCATE TABLE users
        RESTART IDENTITY CASCADE
        """;

    @BeforeEach
    void cleanDatabaseAndStorage() {
        storageService.reset();
        jdbcClient.sql(CLEAN_DATABASE_SQL).update();
    }

    @Test
    void shouldDeleteMediaForOwnerAndCleanupBothStorageObjectsAfterCommit() {
        User owner = saveUser(OWNER_ID);
        User author = saveUser(AUTHOR_ID);
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        Memory memory = saveMemory(MEMORY_ID, story.id(), author.id());
        MediaFile mediaFile = saveMediaFile(MEDIA_ID, memory.id());
        MediaFile other = saveMediaFile(OTHER_MEDIA_ID, memory.id());
        putObjects(mediaFile);
        putObjects(other);

        deleteMediaUseCase.deleteMedia(command(owner.id(), mediaFile.id()));

        assertThat(mediaFileRepository.findById(mediaFile.id())).isEmpty();
        assertThat(mediaFileRepository.findById(other.id())).contains(other);
        assertThat(storageService.deletedKeys).containsExactly(
                new StorageKey(mediaFile.thumbnailStorageKey()),
                new StorageKey(mediaFile.displayStorageKey())
        );
        assertThat(storageService.objects).containsOnlyKeys(
                new StorageKey(other.displayStorageKey()),
                new StorageKey(other.thumbnailStorageKey())
        );
    }

    @Test
    void shouldDeleteMediaForCoOwner() {
        User owner = saveUser(OWNER_ID);
        User coOwner = saveUser(USER_ID);
        User author = saveUser(AUTHOR_ID);
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(story.id(), coOwner.id(), StoryRole.CO_OWNER);
        Memory memory = saveMemory(MEMORY_ID, story.id(), author.id());
        MediaFile mediaFile = saveMediaFile(MEDIA_ID, memory.id());
        putObjects(mediaFile);

        deleteMediaUseCase.deleteMedia(command(coOwner.id(), mediaFile.id()));

        assertThat(mediaFileRepository.findById(mediaFile.id())).isEmpty();
        assertThat(storageService.deletedKeys).hasSize(2);
    }

    @Test
    void shouldDeleteOwnMemoryMediaForEditor() {
        assertAuthorRoleCanDeleteOwnMedia(StoryRole.EDITOR);
    }

    @Test
    void shouldDenyViewerForOwnMemoryMedia() {
        assertDeniedAuthorRoleKeepsMediaAndStorage(StoryRole.VIEWER);
    }

    @Test
    void shouldDenyEditorAndViewerForAnotherAuthorsMemory() {
        assertDeniedRoleKeepsMediaAndStorage(StoryRole.EDITOR);
        cleanDatabaseAndStorage();
        assertDeniedRoleKeepsMediaAndStorage(StoryRole.VIEWER);
    }

    @Test
    void shouldReturnSafeUnavailableForMissingMedia() {
        User user = saveUser(USER_ID);

        assertUnavailable(() -> deleteMediaUseCase.deleteMedia(
                command(user.id(), MEDIA_ID)
        ));

        assertThat(storageService.deletedKeys).isEmpty();
    }

    @Test
    void shouldReturnSafeUnavailableForOutsiderFormerAuthorAndWrongStory() {
        User owner = saveUser(OWNER_ID);
        User requester = saveUser(USER_ID);
        User author = saveUser(AUTHOR_ID);
        User outsider = saveUser(OUTSIDER_ID);
        Story story = saveStory(STORY_ID, owner.id());
        Story otherStory = saveStory(OTHER_STORY_ID, owner.id());
        saveParticipant(otherStory.id(), requester.id(), StoryRole.OWNER);
        Memory memory = saveMemory(MEMORY_ID, story.id(), author.id());
        MediaFile mediaFile = saveMediaFile(MEDIA_ID, memory.id());
        putObjects(mediaFile);

        MediaDeletionUnavailableException outsiderFailure =
                catchUnavailable(() -> deleteMediaUseCase.deleteMedia(
                        command(outsider.id(), mediaFile.id())
                ));
        MediaDeletionUnavailableException formerAuthorFailure =
                catchUnavailable(() -> deleteMediaUseCase.deleteMedia(
                        command(author.id(), mediaFile.id())
                ));
        MediaDeletionUnavailableException wrongStoryFailure =
                catchUnavailable(() -> deleteMediaUseCase.deleteMedia(
                        command(requester.id(), mediaFile.id())
                ));

        assertThat(outsiderFailure.getClass())
                .isEqualTo(formerAuthorFailure.getClass())
                .isEqualTo(wrongStoryFailure.getClass());
        assertThat(outsiderFailure.getMessage())
                .isEqualTo(formerAuthorFailure.getMessage())
                .isEqualTo(wrongStoryFailure.getMessage())
                .isEqualTo("Media could not be deleted");
        assertThat(mediaFileRepository.findById(mediaFile.id()))
                .contains(mediaFile);
        assertThat(storageService.deletedKeys).isEmpty();
    }

    @Test
    void shouldRollbackMetadataDeleteAndSkipStorageCleanupOnOuterRollback() {
        User owner = saveUser(OWNER_ID);
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        Memory memory = saveMemory(MEMORY_ID, story.id(), owner.id());
        MediaFile mediaFile = saveMediaFile(MEDIA_ID, memory.id());
        putObjects(mediaFile);

        assertThatCode(() -> new TransactionTemplate(transactionManager)
                .executeWithoutResult(status -> {
                    deleteMediaUseCase.deleteMedia(command(
                            owner.id(),
                            mediaFile.id()
                    ));
                    status.setRollbackOnly();
                }))
                .doesNotThrowAnyException();

        assertThat(mediaFileRepository.findById(mediaFile.id()))
                .contains(mediaFile);
        assertThat(storageService.deletedKeys).isEmpty();
        assertThat(storageService.objects).containsOnlyKeys(
                new StorageKey(mediaFile.displayStorageKey()),
                new StorageKey(mediaFile.thumbnailStorageKey())
        );
    }

    @Test
    void shouldWaitForOutermostTransactionCommitBeforeCleanup() {
        User owner = saveUser(OWNER_ID);
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        Memory memory = saveMemory(MEMORY_ID, story.id(), owner.id());
        MediaFile mediaFile = saveMediaFile(MEDIA_ID, memory.id());
        putObjects(mediaFile);
        TransactionTemplate transactionTemplate =
                new TransactionTemplate(transactionManager);

        transactionTemplate.executeWithoutResult(status -> {
            deleteMediaUseCase.deleteMedia(command(owner.id(), mediaFile.id()));

            assertThat(mediaFileRepository.findById(mediaFile.id())).isEmpty();
            assertThat(storageService.deletedKeys).isEmpty();
        });

        assertThat(mediaFileRepository.findById(mediaFile.id())).isEmpty();
        assertThat(storageService.deletedKeys).containsExactly(
                new StorageKey(mediaFile.thumbnailStorageKey()),
                new StorageKey(mediaFile.displayStorageKey())
        );
    }

    @Test
    void shouldKeepMetadataDeletedWhenAfterCommitCleanupFails() {
        User owner = saveUser(OWNER_ID);
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        Memory memory = saveMemory(MEMORY_ID, story.id(), owner.id());
        MediaFile mediaFile = saveMediaFile(MEDIA_ID, memory.id());
        putObjects(mediaFile);
        storageService.deleteFailure = new RuntimeException("delete failed");

        deleteMediaUseCase.deleteMedia(command(owner.id(), mediaFile.id()));

        assertThat(mediaFileRepository.findById(mediaFile.id())).isEmpty();
        assertThat(storageService.objects).containsOnlyKeys(
                new StorageKey(mediaFile.displayStorageKey()),
                new StorageKey(mediaFile.thumbnailStorageKey())
        );
        assertThat(storageService.deletedKeys).containsExactly(
                new StorageKey(mediaFile.thumbnailStorageKey()),
                new StorageKey(mediaFile.displayStorageKey())
        );
    }

    private void assertAuthorRoleCanDeleteOwnMedia(StoryRole role) {
        User owner = saveUser(OWNER_ID);
        User author = saveUser(USER_ID);
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(story.id(), author.id(), role);
        Memory memory = saveMemory(MEMORY_ID, story.id(), author.id());
        MediaFile mediaFile = saveMediaFile(MEDIA_ID, memory.id());
        putObjects(mediaFile);

        deleteMediaUseCase.deleteMedia(command(author.id(), mediaFile.id()));

        assertThat(mediaFileRepository.findById(mediaFile.id())).isEmpty();
        assertThat(storageService.deletedKeys).hasSize(2);
    }

    private void assertDeniedRoleKeepsMediaAndStorage(StoryRole role) {
        User owner = saveUser(OWNER_ID);
        User requester = saveUser(USER_ID);
        User author = saveUser(AUTHOR_ID);
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(story.id(), requester.id(), role);
        Memory memory = saveMemory(MEMORY_ID, story.id(), author.id());
        MediaFile mediaFile = saveMediaFile(MEDIA_ID, memory.id());
        putObjects(mediaFile);

        assertUnavailable(() -> deleteMediaUseCase.deleteMedia(
                command(requester.id(), mediaFile.id())
        ));

        assertThat(mediaFileRepository.findById(mediaFile.id()))
                .contains(mediaFile);
        assertThat(storageService.deletedKeys).isEmpty();
    }

    private void assertDeniedAuthorRoleKeepsMediaAndStorage(StoryRole role) {
        User owner = saveUser(OWNER_ID);
        User author = saveUser(USER_ID);
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(story.id(), author.id(), role);
        Memory memory = saveMemory(MEMORY_ID, story.id(), author.id());
        MediaFile mediaFile = saveMediaFile(MEDIA_ID, memory.id());
        putObjects(mediaFile);

        assertUnavailable(() -> deleteMediaUseCase.deleteMedia(
                command(author.id(), mediaFile.id())
        ));

        assertThat(mediaFileRepository.findById(mediaFile.id()))
                .contains(mediaFile);
        assertThat(storageService.deletedKeys).isEmpty();
    }

    private User saveUser(UUID id) {
        return userRepository.save(new User(
                id,
                "google-subject-" + id,
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

    private void saveParticipant(UUID storyId, UUID userId, StoryRole role) {
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

    private MediaFile saveMediaFile(UUID id, UUID memoryId) {
        MediaFile mediaFile = new MediaFile(
                id,
                memoryId,
                MediaType.PHOTO,
                "media/" + id + "/display",
                4L,
                "media/" + id + "/thumbnail",
                2L,
                "image/jpeg",
                BASE_TIME
        );
        mediaFileRepository.save(mediaFile);

        return mediaFile;
    }

    private void putObjects(MediaFile mediaFile) {
        storageService.objects.put(
                new StorageKey(mediaFile.displayStorageKey()),
                new StorageObjectWrite(
                        new StorageKey(mediaFile.displayStorageKey()),
                        new byte[] {1, 2, 3, 4},
                        "image/jpeg"
                )
        );
        storageService.objects.put(
                new StorageKey(mediaFile.thumbnailStorageKey()),
                new StorageObjectWrite(
                        new StorageKey(mediaFile.thumbnailStorageKey()),
                        new byte[] {1, 2},
                        "image/jpeg"
                )
        );
    }

    private static DeleteMediaCommand command(UUID userId, UUID mediaId) {
        return new DeleteMediaCommand(new AuthenticatedUser(userId), mediaId);
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

    @TestConfiguration(proxyBeanMethods = false)
    static class DeleteMediaUseCaseTestConfiguration {

        @Bean
        @Primary
        TestStorageService testStorageService() {
            return new TestStorageService();
        }

        @Bean
        @Primary
        DeleteMediaUseCase testDeleteMediaUseCase(
                MediaFileRepository mediaFileRepository,
                MemoryRepository memoryRepository,
                StoryParticipantRepository storyParticipantRepository,
                DeleteMediaAuthorizationPolicy authorizationPolicy,
                StorageService storageService,
                TransactionCommitCoordinator commitCoordinator
        ) {
            return new TransactionalDeleteMediaService(
                    mediaFileRepository,
                    memoryRepository,
                    storyParticipantRepository,
                    authorizationPolicy,
                    storageService,
                    commitCoordinator
            );
        }
    }

    static final class TestStorageService implements StorageService {

        private final Map<StorageKey, StorageObjectWrite> objects =
                new LinkedHashMap<>();
        private final List<StorageKey> deletedKeys = new ArrayList<>();
        private RuntimeException deleteFailure;

        @Override
        public void store(StorageObjectWrite object) {
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

            if (deleteFailure != null) {
                throw deleteFailure;
            }

            objects.remove(storageKey);
        }

        private void reset() {
            objects.clear();
            deletedKeys.clear();
            deleteFailure = null;
        }
    }

    @FunctionalInterface
    private interface ThrowingAction {

        void run();
    }
}
