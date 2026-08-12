package memory_map.backend.memory.application;

import memory_map.backend.IntegrationTest;
import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.media.domain.MediaFile;
import memory_map.backend.media.domain.MediaType;
import memory_map.backend.media.repository.MediaFileRepository;
import memory_map.backend.media.storage.StorageKey;
import memory_map.backend.media.storage.StorageObjectWrite;
import memory_map.backend.media.storage.StorageService;
import memory_map.backend.media.storage.StoredObject;
import memory_map.backend.memory.domain.Memory;
import memory_map.backend.memory.repository.JdbcMemoryRepository;
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

import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;
import java.util.concurrent.atomic.AtomicInteger;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

@Import(DeleteMemoryUseCaseIntegrationTest.DeleteMemoryUseCaseTestConfiguration.class)
class DeleteMemoryUseCaseIntegrationTest extends IntegrationTest {

    @Autowired
    private DeleteMemoryUseCase deleteMemoryUseCase;

    @Autowired
    private MemoryRepository memoryRepository;

    @Autowired
    private BlockingMemoryRepository blockingMemoryRepository;

    @Autowired
    private MediaFileRepository mediaFileRepository;

    @Autowired
    private TestStorageService storageService;

    @Autowired
    private PlatformTransactionManager transactionManager;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private StoryRepository storyRepository;

    @Autowired
    private StoryParticipantRepository storyParticipantRepository;

    @Autowired
    private JdbcClient jdbcClient;

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
    private static final UUID SECOND_MEMORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000022");
    private static final UUID MISSING_MEMORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000023");
    private static final UUID MEDIA_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000031");
    private static final UUID SECOND_MEDIA_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000032");
    private static final UUID OTHER_MEDIA_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000033");
    private static final Instant BASE_TIME =
            Instant.parse("2026-01-01T10:00:00.123456Z");
    private static final Instant UPDATED_AT =
            Instant.parse("2026-01-03T10:00:00.123456Z");
    private static final LocalDate EVENT_DATE =
            LocalDate.of(2024, 5, 20);
    private static final String CLEAN_DATABASE_SQL = """
        TRUNCATE TABLE users
        RESTART IDENTITY CASCADE
        """;

    @BeforeEach
    void cleanDatabase() {
        blockingMemoryRepository.reset();
        storageService.reset();
        jdbcClient.sql(CLEAN_DATABASE_SQL).update();
    }

    @Test
    void shouldDeleteMemoryForOwnerEvenWhenNotAuthor() {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        User author = saveUser(AUTHOR_ID, "author-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        saveParticipant(story.id(), author.id(), StoryRole.EDITOR);
        Memory target = saveMemory(MEMORY_ID, story.id(), author.id());
        Memory untouched = saveMemory(
                SECOND_MEMORY_ID,
                story.id(),
                owner.id(),
                "Second memory"
        );

        deleteMemoryUseCase.deleteMemory(command(owner.id(), target.id()));

        assertThat(memoryRepository.findById(target.id())).isEmpty();
        assertThat(memoryRepository.findById(untouched.id()))
                .contains(untouched);
        assertThat(storyRepository.findById(story.id()))
                .contains(story);
        assertThat(storyParticipantRepository.find(story.id(), owner.id()))
                .isPresent();
        assertThat(storageService.deletedKeys).isEmpty();
    }

    @Test
    void shouldDeleteMemoryForCoOwnerEvenWhenNotAuthor() {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        User coOwner = saveUser(USER_ID, "co-owner-google-subject");
        User author = saveUser(AUTHOR_ID, "author-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(story.id(), coOwner.id(), StoryRole.CO_OWNER);
        Memory memory = saveMemory(MEMORY_ID, story.id(), author.id());

        deleteMemoryUseCase.deleteMemory(command(coOwner.id(), memory.id()));

        assertThat(memoryRepository.findById(memory.id())).isEmpty();
    }

    @Test
    void shouldDeleteOwnMemoryForEditor() {

        assertAuthorRoleCanDeleteOwnMemory(StoryRole.EDITOR);
    }

    @Test
    void shouldDeleteOwnMemoryForViewer() {

        assertAuthorRoleCanDeleteOwnMemory(StoryRole.VIEWER);
    }

    @Test
    void shouldDenyEditorForAnotherAuthorsMemory() {

        assertDeniedRoleKeepsMemory(StoryRole.EDITOR);
    }

    @Test
    void shouldDenyViewerForAnotherAuthorsMemory() {

        assertDeniedRoleKeepsMemory(StoryRole.VIEWER);
    }

    @Test
    void shouldDenyOutsider() {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        User outsider = saveUser(USER_ID, "outsider-google-subject");
        User author = saveUser(AUTHOR_ID, "author-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        Memory memory = saveMemory(MEMORY_ID, story.id(), author.id());

        assertMemoryUnavailable(() -> deleteMemoryUseCase.deleteMemory(
                command(outsider.id(), memory.id())
        ));

        assertThat(memoryRepository.findById(memory.id()))
                .contains(memory);
    }

    @Test
    void shouldDenyFormerAuthorWithoutMembership() {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        User author = saveUser(USER_ID, "author-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        Memory memory = saveMemory(MEMORY_ID, story.id(), author.id());

        assertMemoryUnavailable(() -> deleteMemoryUseCase.deleteMemory(
                command(author.id(), memory.id())
        ));

        assertThat(memoryRepository.findById(memory.id()))
                .contains(memory);
    }

    @Test
    void shouldDenyStoryOwnerWithoutMembership() {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        User author = saveUser(AUTHOR_ID, "author-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        Memory memory = saveMemory(MEMORY_ID, story.id(), author.id());

        assertMemoryUnavailable(() -> deleteMemoryUseCase.deleteMemory(
                command(owner.id(), memory.id())
        ));

        assertThat(memoryRepository.findById(memory.id()))
                .contains(memory);
    }

    @Test
    void shouldDenyParticipantOfAnotherStory() {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        User user = saveUser(USER_ID, "current-google-subject");
        User author = saveUser(AUTHOR_ID, "author-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        Story otherStory = saveStory(OTHER_STORY_ID, owner.id());
        saveParticipant(otherStory.id(), user.id(), StoryRole.OWNER);
        Memory memory = saveMemory(MEMORY_ID, story.id(), author.id());

        assertMemoryUnavailable(() -> deleteMemoryUseCase.deleteMemory(
                command(user.id(), memory.id())
        ));

        assertThat(memoryRepository.findById(memory.id()))
                .contains(memory);
    }

    @Test
    void shouldThrowMemoryUnavailableWhenMemoryIsMissing() {

        User user = saveUser(USER_ID, "current-google-subject");

        assertMemoryUnavailable(() -> deleteMemoryUseCase.deleteMemory(
                command(user.id(), MISSING_MEMORY_ID)
        ));
    }

    @Test
    void shouldThrowMemoryUnavailableWhenDeletingMemoryTwice() {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        Memory memory = saveMemory(MEMORY_ID, story.id(), owner.id());
        DeleteMemoryCommand command = command(owner.id(), memory.id());

        deleteMemoryUseCase.deleteMemory(command);

        assertMemoryUnavailable(() -> deleteMemoryUseCase.deleteMemory(
                command
        ));
        assertThat(memoryRepository.findById(memory.id())).isEmpty();
    }

    @Test
    void shouldCascadeDeleteMediaMetadataForDeletedMemoryOnly() {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        Memory target = saveMemory(MEMORY_ID, story.id(), owner.id());
        Memory untouched = saveMemory(
                SECOND_MEMORY_ID,
                story.id(),
                owner.id(),
                "Second memory"
        );
        MediaFile first = saveMediaFile(MEDIA_ID, target.id());
        MediaFile second = saveMediaFile(SECOND_MEDIA_ID, target.id());
        MediaFile other = saveMediaFile(OTHER_MEDIA_ID, untouched.id());

        deleteMemoryUseCase.deleteMemory(command(owner.id(), target.id()));

        assertThat(mediaFileRepository.findById(first.id())).isEmpty();
        assertThat(mediaFileRepository.findById(second.id())).isEmpty();
        assertThat(mediaFileRepository.findById(other.id()))
                .contains(other);
        assertThat(memoryRepository.findById(untouched.id()))
                .contains(untouched);
        assertThat(storageService.deletedKeys).containsExactly(
                thumbnailKey(first),
                displayKey(first),
                thumbnailKey(second),
                displayKey(second)
        );
    }

    @Test
    void shouldCleanupOneMediaFileAfterMemoryDeleteCommit() {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        Memory memory = saveMemory(MEMORY_ID, story.id(), owner.id());
        MediaFile mediaFile = saveMediaFile(MEDIA_ID, memory.id());

        deleteMemoryUseCase.deleteMemory(command(owner.id(), memory.id()));

        assertThat(memoryRepository.findById(memory.id())).isEmpty();
        assertThat(mediaFileRepository.findById(mediaFile.id())).isEmpty();
        assertThat(storageService.deletedKeys).containsExactly(
                thumbnailKey(mediaFile),
                displayKey(mediaFile)
        );
    }

    @Test
    void shouldCleanupAllMediaFilesAndContinueAfterStorageFailure() {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        Memory memory = saveMemory(MEMORY_ID, story.id(), owner.id());
        MediaFile first = saveMediaFile(MEDIA_ID, memory.id());
        MediaFile second = saveMediaFile(SECOND_MEDIA_ID, memory.id());
        MediaFile third = saveMediaFile(OTHER_MEDIA_ID, memory.id());
        storageService.failingKeys = List.of(
                displayKey(first),
                thumbnailKey(third)
        );

        deleteMemoryUseCase.deleteMemory(command(owner.id(), memory.id()));

        assertThat(memoryRepository.findById(memory.id())).isEmpty();
        assertThat(mediaFileRepository.findByMemoryId(memory.id())).isEmpty();
        assertThat(storageService.deletedKeys).containsExactly(
                thumbnailKey(first),
                displayKey(first),
                thumbnailKey(second),
                displayKey(second),
                thumbnailKey(third),
                displayKey(third)
        );
    }

    @Test
    void shouldNotCleanupStorageWhenOuterTransactionRollsBack() {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        Memory memory = saveMemory(MEMORY_ID, story.id(), owner.id());
        MediaFile mediaFile = saveMediaFile(MEDIA_ID, memory.id());

        assertThatCode(() -> new TransactionTemplate(transactionManager)
                .executeWithoutResult(status -> {
                    deleteMemoryUseCase.deleteMemory(command(
                            owner.id(),
                            memory.id()
                    ));
                    assertThat(memoryRepository.findById(memory.id()))
                            .isEmpty();
                    assertThat(mediaFileRepository.findById(mediaFile.id()))
                            .isEmpty();
                    assertThat(storageService.deletedKeys).isEmpty();
                    status.setRollbackOnly();
                }))
                .doesNotThrowAnyException();

        assertThat(memoryRepository.findById(memory.id())).contains(memory);
        assertThat(mediaFileRepository.findById(mediaFile.id()))
                .contains(mediaFile);
        assertThat(storageService.deletedKeys).isEmpty();
    }

    @Test
    void shouldRollbackMemoryAndMediaMetadataWhenDeleteRepositoryFails() {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        Memory memory = saveMemory(MEMORY_ID, story.id(), owner.id());
        MediaFile mediaFile = saveMediaFile(MEDIA_ID, memory.id());
        blockingMemoryRepository.failAfterDelete(
                new RuntimeException("memory delete failed after write")
        );

        assertThatThrownBy(() -> deleteMemoryUseCase.deleteMemory(
                command(owner.id(), memory.id())
        ))
                .isInstanceOf(RuntimeException.class)
                .hasMessage("memory delete failed after write")
                .isNotInstanceOf(MemoryDeletionUnavailableException.class);

        assertThat(memoryRepository.findById(memory.id()))
                .contains(memory);
        assertThat(mediaFileRepository.findById(mediaFile.id()))
                .contains(mediaFile);
        assertThat(storageService.deletedKeys).isEmpty();
    }

    @Test
    void shouldSerializeConcurrentDeletesAndReturnUnavailableForSecond()
            throws Exception {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        Memory memory = saveMemory(MEMORY_ID, story.id(), owner.id());
        ExecutorService executor = Executors.newFixedThreadPool(2);
        blockingMemoryRepository.blockFirstFindByIdForUpdate();

        try {
            Future<Void> first = executor.submit(() -> {
                deleteMemoryUseCase.deleteMemory(command(
                        owner.id(),
                        memory.id()
                ));
                return null;
            });

            blockingMemoryRepository.awaitFirstLockAcquired();

            Future<Void> second = executor.submit(() -> {
                deleteMemoryUseCase.deleteMemory(command(
                        owner.id(),
                        memory.id()
                ));
                return null;
            });

            blockingMemoryRepository.awaitSecondLockAttemptStarted();
            assertThatThrownBy(() -> second.get(250, TimeUnit.MILLISECONDS))
                    .isInstanceOf(TimeoutException.class);

            blockingMemoryRepository.releaseFirstTransaction();

            assertThat(first.get(10, TimeUnit.SECONDS)).isNull();
            assertThatThrownBy(() -> second.get(10, TimeUnit.SECONDS))
                    .isInstanceOf(ExecutionException.class)
                    .hasCauseInstanceOf(
                            MemoryDeletionUnavailableException.class
                    );
            assertThat(memoryRepository.findById(memory.id())).isEmpty();
        } finally {
            blockingMemoryRepository.releaseFirstTransaction();
            executor.shutdownNow();
        }
    }

    private void assertAuthorRoleCanDeleteOwnMemory(StoryRole role) {
        User owner = saveUser(OWNER_ID, "owner-google-subject");
        User author = saveUser(USER_ID, "author-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(story.id(), author.id(), role);
        Memory memory = saveMemory(MEMORY_ID, story.id(), author.id());

        deleteMemoryUseCase.deleteMemory(command(author.id(), memory.id()));

        assertThat(memoryRepository.findById(memory.id())).isEmpty();
    }

    private void assertDeniedRoleKeepsMemory(StoryRole role) {
        User owner = saveUser(OWNER_ID, "owner-google-subject");
        User user = saveUser(USER_ID, "current-google-subject");
        User author = saveUser(AUTHOR_ID, "author-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(story.id(), user.id(), role);
        Memory memory = saveMemory(MEMORY_ID, story.id(), author.id());

        MemoryDeletionUnavailableException denied =
                catchMemoryUnavailable(() -> deleteMemoryUseCase.deleteMemory(
                        command(user.id(), memory.id())
                ));
        MemoryDeletionUnavailableException missing =
                catchMemoryUnavailable(() -> deleteMemoryUseCase.deleteMemory(
                        command(user.id(), MISSING_MEMORY_ID)
                ));

        assertThat(denied.getClass()).isEqualTo(missing.getClass());
        assertThat(denied.getMessage())
                .isEqualTo(missing.getMessage())
                .isEqualTo("Memory could not be deleted");
        assertThat(memoryRepository.findById(memory.id()))
                .contains(memory);
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

    private Memory saveMemory(
            UUID id,
            UUID storyId,
            UUID createdBy
    ) {
        return saveMemory(id, storyId, createdBy, "First trip");
    }

    private Memory saveMemory(
            UUID id,
            UUID storyId,
            UUID createdBy,
            String title
    ) {
        Memory memory = new Memory(
                id,
                storyId,
                createdBy,
                title,
                "A spring walk",
                "Tbilisi",
                41.715137,
                44.827096,
                EVENT_DATE,
                BASE_TIME,
                UPDATED_AT
        );
        memoryRepository.save(memory);

        return memory;
    }

    private MediaFile saveMediaFile(UUID id, UUID memoryId) {
        MediaFile mediaFile = new MediaFile(
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
        mediaFileRepository.save(mediaFile);

        return mediaFile;
    }

    private static StorageKey thumbnailKey(MediaFile mediaFile) {
        return new StorageKey(mediaFile.thumbnailStorageKey());
    }

    private static StorageKey displayKey(MediaFile mediaFile) {
        return new StorageKey(mediaFile.displayStorageKey());
    }

    private static DeleteMemoryCommand command(UUID userId, UUID memoryId) {
        return new DeleteMemoryCommand(
                new AuthenticatedUser(userId),
                memoryId
        );
    }

    private static void assertMemoryUnavailable(ThrowingAction action) {
        assertThatThrownBy(action::run)
                .isInstanceOf(MemoryDeletionUnavailableException.class)
                .hasMessage("Memory could not be deleted");
    }

    private static MemoryDeletionUnavailableException catchMemoryUnavailable(
            ThrowingAction action
    ) {
        try {
            action.run();
        } catch (MemoryDeletionUnavailableException exception) {
            return exception;
        }

        throw new AssertionError("Expected MemoryDeletionUnavailableException");
    }

    @TestConfiguration(proxyBeanMethods = false)
    static class DeleteMemoryUseCaseTestConfiguration {

        @Bean
        @Primary
        BlockingMemoryRepository blockingMemoryRepository(
                JdbcMemoryRepository delegate,
                MediaFileRepository mediaFileRepository
        ) {
            return new BlockingMemoryRepository(
                    delegate,
                    mediaFileRepository
            );
        }

        @Bean
        @Primary
        TestStorageService testStorageService() {
            return new TestStorageService();
        }
    }

    static final class TestStorageService implements StorageService {

        private final List<StorageKey> deletedKeys = new ArrayList<>();
        private List<StorageKey> failingKeys = List.of();

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

            if (failingKeys.contains(storageKey)) {
                throw new RuntimeException("storage delete failed");
            }
        }

        private void reset() {
            deletedKeys.clear();
            failingKeys = List.of();
        }
    }

    static final class BlockingMemoryRepository implements MemoryRepository {

        private final MemoryRepository delegate;
        private final MediaFileRepository mediaFileRepository;
        private final AtomicInteger findForUpdateCalls = new AtomicInteger();
        private volatile CountDownLatch firstLockAcquired =
                new CountDownLatch(0);
        private volatile CountDownLatch releaseFirstTransaction =
                new CountDownLatch(0);
        private volatile CountDownLatch secondLockAttemptStarted =
                new CountDownLatch(0);
        private volatile boolean blockFirstFindByIdForUpdate;
        private RuntimeException deleteFailure;

        private BlockingMemoryRepository(
                MemoryRepository delegate,
                MediaFileRepository mediaFileRepository
        ) {
            this.delegate = delegate;
            this.mediaFileRepository = mediaFileRepository;
        }

        @Override
        public Optional<Memory> findById(UUID id) {
            return delegate.findById(id);
        }

        @Override
        public Optional<Memory> findByIdForUpdate(UUID id) {
            if (!blockFirstFindByIdForUpdate) {
                return delegate.findByIdForUpdate(id);
            }

            int call = findForUpdateCalls.incrementAndGet();

            if (call == 1) {
                Optional<Memory> memory = delegate.findByIdForUpdate(id);
                firstLockAcquired.countDown();
                await(releaseFirstTransaction);

                return memory;
            }

            if (call == 2) {
                secondLockAttemptStarted.countDown();
            }

            return delegate.findByIdForUpdate(id);
        }

        @Override
        public List<Memory> findByStoryId(UUID storyId) {
            return delegate.findByStoryId(storyId);
        }

        @Override
        public void save(Memory memory) {
            delegate.save(memory);
        }

        @Override
        public boolean update(Memory memory) {
            return delegate.update(memory);
        }

        @Override
        public boolean delete(UUID id) {
            boolean deleted = delegate.delete(id);

            if (deleteFailure != null) {
                assertThat(deleted).isTrue();
                assertThat(delegate.findById(id)).isEmpty();
                assertThat(mediaFileRepository.findByMemoryId(id)).isEmpty();

                throw deleteFailure;
            }

            return deleted;
        }

        private void failAfterDelete(RuntimeException failure) {
            deleteFailure = failure;
        }

        private void blockFirstFindByIdForUpdate() {
            findForUpdateCalls.set(0);
            firstLockAcquired = new CountDownLatch(1);
            releaseFirstTransaction = new CountDownLatch(1);
            secondLockAttemptStarted = new CountDownLatch(1);
            blockFirstFindByIdForUpdate = true;
        }

        private void awaitFirstLockAcquired() {
            await(firstLockAcquired);
        }

        private void awaitSecondLockAttemptStarted() {
            await(secondLockAttemptStarted);
        }

        private void releaseFirstTransaction() {
            releaseFirstTransaction.countDown();
        }

        private void reset() {
            deleteFailure = null;
            blockFirstFindByIdForUpdate = false;
            findForUpdateCalls.set(0);
            firstLockAcquired = new CountDownLatch(0);
            releaseFirstTransaction = new CountDownLatch(0);
            secondLockAttemptStarted = new CountDownLatch(0);
        }
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

    @FunctionalInterface
    private interface ThrowingAction {

        void run();
    }
}
