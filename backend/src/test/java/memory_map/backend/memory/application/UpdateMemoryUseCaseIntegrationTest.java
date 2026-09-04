package memory_map.backend.memory.application;

import memory_map.backend.IntegrationTest;
import memory_map.backend.auth.domain.AuthenticatedUser;
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

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;
import java.util.concurrent.atomic.AtomicInteger;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.assertj.core.api.Assertions.within;

@Import(UpdateMemoryUseCaseIntegrationTest.UpdateMemoryUseCaseTestConfiguration.class)
class UpdateMemoryUseCaseIntegrationTest extends IntegrationTest {

    @Autowired
    private UpdateMemoryUseCase updateMemoryUseCase;

    @Autowired
    private MemoryRepository memoryRepository;

    @Autowired
    private BlockingMemoryRepository blockingMemoryRepository;

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
    private static final UUID MISSING_MEMORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000022");
    private static final Instant BASE_TIME =
            Instant.parse("2026-01-01T10:00:00.123456Z");
    private static final Instant UPDATED_AT =
            Instant.parse("2026-01-03T10:00:00.123456Z");
    private static final Instant CURRENT_TIME =
            Instant.parse("2026-01-10T10:00:00.123456Z");
    private static final Instant SECOND_CURRENT_TIME =
            Instant.parse("2026-01-10T10:01:00.123456Z");
    private static final LocalDate EVENT_DATE =
            LocalDate.of(2024, 5, 20);
    private static final String CLEAN_DATABASE_SQL = """
        TRUNCATE TABLE users
        RESTART IDENTITY CASCADE
        """;

    @BeforeEach
    void cleanDatabase() {
        blockingMemoryRepository.reset();
        jdbcClient.sql(CLEAN_DATABASE_SQL).update();
    }

    @Test
    void shouldUpdateMemoryForOwnerEvenWhenNotAuthor() {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        User author = saveUser(AUTHOR_ID, "author-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        Memory memory = saveMemory(story.id(), author.id());

        Memory result = updateMemoryUseCase.updateMemory(command(
                owner.id(),
                memory.id(),
                PatchField.provided("Updated memory"),
                notProvided(),
                notProvided(),
                notProvided(),
                notProvided(),
                notProvided(),
                CURRENT_TIME
        ));

        Memory persisted = memoryRepository.findById(memory.id())
                .orElseThrow();

        assertMemoryMatches(result, persisted);
        assertThat(persisted.id()).isEqualTo(memory.id());
        assertThat(persisted.storyId()).isEqualTo(story.id());
        assertThat(persisted.createdBy()).isEqualTo(author.id());
        assertThat(persisted.createdAt()).isEqualTo(memory.createdAt());
        assertThat(persisted.title()).isEqualTo("Updated memory");
        assertThat(persisted.description()).isEqualTo(memory.description());
        assertThat(persisted.updatedAt()).isEqualTo(CURRENT_TIME);
    }

    @Test
    void shouldUpdateMemoryForCoOwnerEvenWhenNotAuthor() {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        User coOwner = saveUser(USER_ID, "co-owner-google-subject");
        User author = saveUser(AUTHOR_ID, "author-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(story.id(), coOwner.id(), StoryRole.CO_OWNER);
        Memory memory = saveMemory(story.id(), author.id());

        Memory result = updateMemoryUseCase.updateMemory(command(
                coOwner.id(),
                memory.id(),
                notProvided(),
                PatchField.provided("Updated description"),
                notProvided(),
                notProvided(),
                notProvided(),
                notProvided(),
                CURRENT_TIME
        ));

        assertThat(result.description()).isEqualTo("Updated description");
        assertMemoryMatches(
                memoryRepository.findById(memory.id()).orElseThrow(),
                result
        );
    }

    @Test
    void shouldUpdateOwnMemoryForEditor() {

        assertAuthorRoleCanUpdateOwnMemory(StoryRole.EDITOR);
    }

    @Test
    void shouldDenyViewerForOwnMemory() {

        assertDeniedAuthorRoleKeepsMemoryUnchanged(StoryRole.VIEWER);
    }

    @Test
    void shouldDenyEditorForAnotherAuthorsMemory() {

        assertDeniedRoleKeepsMemoryUnchanged(StoryRole.EDITOR);
    }

    @Test
    void shouldDenyViewerForAnotherAuthorsMemory() {

        assertDeniedRoleKeepsMemoryUnchanged(StoryRole.VIEWER);
    }

    @Test
    void shouldDenyFormerAuthorWithoutMembership() {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        User author = saveUser(USER_ID, "author-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        Memory memory = saveMemory(story.id(), author.id());

        assertMemoryUnavailable(() -> updateMemoryUseCase.updateMemory(
                titleCommand(author.id(), memory.id(), "Updated memory")
        ));

        assertThat(memoryRepository.findById(memory.id()))
                .contains(memory);
    }

    @Test
    void shouldDenyStoryOwnerWithoutMembership() {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        User author = saveUser(AUTHOR_ID, "author-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        Memory memory = saveMemory(story.id(), author.id());

        assertMemoryUnavailable(() -> updateMemoryUseCase.updateMemory(
                titleCommand(owner.id(), memory.id(), "Updated memory")
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
        Memory memory = saveMemory(story.id(), author.id());

        assertMemoryUnavailable(() -> updateMemoryUseCase.updateMemory(
                titleCommand(user.id(), memory.id(), "Updated memory")
        ));

        assertThat(memoryRepository.findById(memory.id()))
                .contains(memory);
    }

    @Test
    void shouldThrowMemoryUnavailableWhenMemoryIsMissing() {

        User user = saveUser(USER_ID, "current-google-subject");

        assertMemoryUnavailable(() -> updateMemoryUseCase.updateMemory(
                titleCommand(user.id(), MISSING_MEMORY_ID, "Updated memory")
        ));
    }

    @Test
    void shouldSkipSameValueNoOpAndKeepUpdatedAt() {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        Memory memory = saveMemory(story.id(), owner.id());

        Memory result = updateMemoryUseCase.updateMemory(command(
                owner.id(),
                memory.id(),
                PatchField.provided(memory.title()),
                PatchField.provided(memory.description()),
                PatchField.provided(memory.placeName()),
                PatchField.provided(memory.latitude()),
                PatchField.provided(memory.longitude()),
                PatchField.provided(memory.eventDate()),
                CURRENT_TIME
        ));

        assertMemoryMatches(result, memory);
        assertThat(result.updatedAt()).isEqualTo(UPDATED_AT);
        assertThat(memoryRepository.findById(memory.id()))
                .contains(memory);
    }

    @Test
    void shouldClearNullableFields() {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        Memory memory = saveMemory(story.id(), owner.id());

        Memory result = updateMemoryUseCase.updateMemory(command(
                owner.id(),
                memory.id(),
                notProvided(),
                PatchField.provided(null),
                PatchField.provided(null),
                notProvided(),
                notProvided(),
                notProvided(),
                CURRENT_TIME
        ));

        Memory persisted = memoryRepository.findById(memory.id())
                .orElseThrow();

        assertThat(result.description()).isNull();
        assertThat(result.placeName()).isNull();
        assertThat(persisted.description()).isNull();
        assertThat(persisted.placeName()).isNull();
        assertThat(persisted.updatedAt()).isEqualTo(CURRENT_TIME);
    }

    @Test
    void shouldUpdatePostgisLocationWithoutSwappingCoordinates() {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        Memory memory = saveMemory(story.id(), owner.id());

        updateMemoryUseCase.updateMemory(command(
                owner.id(),
                memory.id(),
                notProvided(),
                notProvided(),
                notProvided(),
                PatchField.provided(41.7151),
                PatchField.provided(44.8271),
                notProvided(),
                CURRENT_TIME
        ));

        Memory persisted = memoryRepository.findById(memory.id())
                .orElseThrow();
        Integer srid = jdbcClient.sql("""
                SELECT ST_SRID(location::geometry)
                FROM memories
                WHERE id = :id
                """)
                .param("id", memory.id())
                .query(Integer.class)
                .single();

        assertThat(persisted.latitude()).isCloseTo(41.7151, within(0.000001));
        assertThat(persisted.longitude()).isCloseTo(44.8271, within(0.000001));
        assertThat(srid).isEqualTo(4326);
    }

    @Test
    void shouldRollbackMemoryUpdateWhenRepositoryFailsAfterDatabaseUpdate() {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        Memory memory = saveMemory(story.id(), owner.id());
        blockingMemoryRepository.failAfterUpdate(
                new RuntimeException("memory update failed after write")
        );

        assertThatThrownBy(() -> updateMemoryUseCase.updateMemory(
                titleCommand(owner.id(), memory.id(), "Updated memory")
        ))
                .isInstanceOf(RuntimeException.class)
                .hasMessage("memory update failed after write")
                .isNotInstanceOf(MemoryUpdateUnavailableException.class);

        assertThat(memoryRepository.findById(memory.id()))
                .contains(memory);
    }

    @Test
    void shouldSerializeConcurrentPartialUpdatesWithoutLostUpdate()
            throws Exception {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        Memory memory = saveMemory(
                story.id(),
                owner.id(),
                "A",
                "D0",
                "Tbilisi",
                41.715137,
                44.827096,
                EVENT_DATE
        );
        ExecutorService executor = Executors.newFixedThreadPool(2);
        blockingMemoryRepository.blockFirstFindByIdForUpdate();

        try {
            Future<Memory> first = executor.submit(() ->
                    updateMemoryUseCase.updateMemory(command(
                            owner.id(),
                            memory.id(),
                            PatchField.provided("B"),
                            notProvided(),
                            notProvided(),
                            notProvided(),
                            notProvided(),
                            notProvided(),
                            CURRENT_TIME
                    ))
            );

            blockingMemoryRepository.awaitFirstLockAcquired();

            Future<Memory> second = executor.submit(() ->
                    updateMemoryUseCase.updateMemory(command(
                            owner.id(),
                            memory.id(),
                            notProvided(),
                            PatchField.provided("D1"),
                            notProvided(),
                            notProvided(),
                            notProvided(),
                            notProvided(),
                            SECOND_CURRENT_TIME
                    ))
            );

            blockingMemoryRepository.awaitSecondLockAttemptStarted();
            assertThatThrownBy(() -> second.get(250, TimeUnit.MILLISECONDS))
                    .isInstanceOf(TimeoutException.class);

            blockingMemoryRepository.releaseFirstTransaction();

            Memory firstResult = first.get(10, TimeUnit.SECONDS);
            Memory secondResult = second.get(10, TimeUnit.SECONDS);
            Memory persisted = memoryRepository.findById(memory.id())
                    .orElseThrow();

            assertThat(firstResult.title()).isEqualTo("B");
            assertThat(firstResult.description()).isEqualTo("D0");
            assertThat(secondResult.title()).isEqualTo("B");
            assertThat(secondResult.description()).isEqualTo("D1");
            assertThat(persisted.title()).isEqualTo("B");
            assertThat(persisted.description()).isEqualTo("D1");
            assertThat(persisted.updatedAt()).isEqualTo(SECOND_CURRENT_TIME);
        } finally {
            blockingMemoryRepository.releaseFirstTransaction();
            executor.shutdownNow();
        }
    }

    private void assertAuthorRoleCanUpdateOwnMemory(StoryRole role) {
        User owner = saveUser(OWNER_ID, "owner-google-subject");
        User author = saveUser(USER_ID, "author-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(story.id(), author.id(), role);
        Memory memory = saveMemory(story.id(), author.id());

        Memory result = updateMemoryUseCase.updateMemory(command(
                author.id(),
                memory.id(),
                notProvided(),
                notProvided(),
                PatchField.provided("Kutaisi"),
                notProvided(),
                notProvided(),
                notProvided(),
                CURRENT_TIME
        ));

        assertThat(result.placeName()).isEqualTo("Kutaisi");
        assertMemoryMatches(
                memoryRepository.findById(memory.id()).orElseThrow(),
                result
        );
    }

    private void assertDeniedRoleKeepsMemoryUnchanged(StoryRole role) {
        User owner = saveUser(OWNER_ID, "owner-google-subject");
        User user = saveUser(USER_ID, "current-google-subject");
        User author = saveUser(AUTHOR_ID, "author-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(story.id(), user.id(), role);
        Memory memory = saveMemory(story.id(), author.id());

        MemoryUpdateUnavailableException denied =
                catchMemoryUnavailable(() -> updateMemoryUseCase.updateMemory(
                        titleCommand(user.id(), memory.id(), "Updated memory")
                ));
        MemoryUpdateUnavailableException missing =
                catchMemoryUnavailable(() -> updateMemoryUseCase.updateMemory(
                        titleCommand(user.id(), MISSING_MEMORY_ID, "Missing")
                ));

        assertThat(denied.getClass()).isEqualTo(missing.getClass());
        assertThat(denied.getMessage())
                .isEqualTo(missing.getMessage())
                .isEqualTo("Memory could not be updated");
        assertThat(memoryRepository.findById(memory.id()))
                .contains(memory);
    }

    private void assertDeniedAuthorRoleKeepsMemoryUnchanged(StoryRole role) {
        User owner = saveUser(OWNER_ID, "owner-google-subject");
        User author = saveUser(USER_ID, "author-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(story.id(), author.id(), role);
        Memory memory = saveMemory(story.id(), author.id());

        assertMemoryUnavailable(() -> updateMemoryUseCase.updateMemory(
                titleCommand(author.id(), memory.id(), "Updated memory")
        ));

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

    private Memory saveMemory(UUID storyId, UUID createdBy) {
        return saveMemory(
                storyId,
                createdBy,
                "First trip",
                "A spring walk",
                "Tbilisi",
                41.715137,
                44.827096,
                EVENT_DATE
        );
    }

    private Memory saveMemory(
            UUID storyId,
            UUID createdBy,
            String title,
            String description,
            String placeName,
            double latitude,
            double longitude,
            LocalDate eventDate
    ) {
        Memory memory = new Memory(
                MEMORY_ID,
                storyId,
                createdBy,
                title,
                description,
                placeName,
                latitude,
                longitude,
                eventDate,
                BASE_TIME,
                UPDATED_AT
        );
        memoryRepository.save(memory);

        return memory;
    }

    private static UpdateMemoryCommand titleCommand(
            UUID userId,
            UUID memoryId,
            String title
    ) {
        return command(
                userId,
                memoryId,
                PatchField.provided(title),
                notProvided(),
                notProvided(),
                notProvided(),
                notProvided(),
                notProvided(),
                CURRENT_TIME
        );
    }

    private static UpdateMemoryCommand command(
            UUID userId,
            UUID memoryId,
            PatchField<String> title,
            PatchField<String> description,
            PatchField<String> placeName,
            PatchField<Double> latitude,
            PatchField<Double> longitude,
            PatchField<LocalDate> eventDate,
            Instant currentTime
    ) {
        return new UpdateMemoryCommand(
                new AuthenticatedUser(userId),
                memoryId,
                title,
                description,
                placeName,
                latitude,
                longitude,
                eventDate,
                currentTime
        );
    }

    private static void assertMemoryMatches(
            Memory actual,
            Memory expected
    ) {
        assertThat(actual.id()).isEqualTo(expected.id());
        assertThat(actual.storyId()).isEqualTo(expected.storyId());
        assertThat(actual.createdBy()).isEqualTo(expected.createdBy());
        assertThat(actual.title()).isEqualTo(expected.title());
        assertThat(actual.description()).isEqualTo(expected.description());
        assertThat(actual.placeName()).isEqualTo(expected.placeName());
        assertThat(actual.latitude())
                .isCloseTo(expected.latitude(), within(0.000001));
        assertThat(actual.longitude())
                .isCloseTo(expected.longitude(), within(0.000001));
        assertThat(actual.eventDate()).isEqualTo(expected.eventDate());
        assertThat(actual.createdAt()).isEqualTo(expected.createdAt());
        assertThat(actual.updatedAt()).isEqualTo(expected.updatedAt());
    }

    private static void assertMemoryUnavailable(ThrowingAction action) {
        assertThatThrownBy(action::run)
                .isInstanceOf(MemoryUpdateUnavailableException.class)
                .hasMessage("Memory could not be updated");
    }

    private static MemoryUpdateUnavailableException catchMemoryUnavailable(
            ThrowingAction action
    ) {
        try {
            action.run();
        } catch (MemoryUpdateUnavailableException exception) {
            return exception;
        }

        throw new AssertionError("Expected MemoryUpdateUnavailableException");
    }

    private static <T> PatchField<T> notProvided() {
        return PatchField.notProvided();
    }

    @TestConfiguration(proxyBeanMethods = false)
    static class UpdateMemoryUseCaseTestConfiguration {

        @Bean
        @Primary
        BlockingMemoryRepository blockingMemoryRepository(
                JdbcMemoryRepository delegate
        ) {
            return new BlockingMemoryRepository(delegate);
        }
    }

    static final class BlockingMemoryRepository implements MemoryRepository {

        private final MemoryRepository delegate;
        private final AtomicInteger findForUpdateCalls = new AtomicInteger();
        private volatile CountDownLatch firstLockAcquired =
                new CountDownLatch(0);
        private volatile CountDownLatch releaseFirstTransaction =
                new CountDownLatch(0);
        private volatile CountDownLatch secondLockAttemptStarted =
                new CountDownLatch(0);
        private volatile boolean blockFirstFindByIdForUpdate;
        private RuntimeException updateFailure;

        private BlockingMemoryRepository(MemoryRepository delegate) {
            this.delegate = delegate;
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
            boolean updated = delegate.update(memory);

            if (updateFailure != null) {
                Memory loaded = delegate.findById(memory.id())
                        .orElseThrow();
                assertThat(loaded.title()).isEqualTo(memory.title());
                assertThat(loaded.updatedAt()).isEqualTo(memory.updatedAt());

                throw updateFailure;
            }

            return updated;
        }

        @Override
        public boolean delete(UUID id) {
            return delegate.delete(id);
        }

        private void failAfterUpdate(RuntimeException failure) {
            updateFailure = failure;
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
            updateFailure = null;
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
