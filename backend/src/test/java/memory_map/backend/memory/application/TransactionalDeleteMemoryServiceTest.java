package memory_map.backend.memory.application;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.memory.domain.Memory;
import memory_map.backend.memory.repository.MemoryRepository;
import memory_map.backend.storyparticipant.domain.StoryParticipant;
import memory_map.backend.storyparticipant.domain.StoryRole;
import memory_map.backend.storyparticipant.repository.StoryParticipantRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;
import org.springframework.transaction.annotation.Transactional;

import java.lang.reflect.Method;
import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class TransactionalDeleteMemoryServiceTest {

    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID AUTHOR_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000002");
    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000011");
    private static final UUID OTHER_STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000012");
    private static final UUID MEMORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000021");
    private static final Instant JOINED_AT =
            Instant.parse("2026-01-01T10:00:00.123456Z");
    private static final Instant CREATED_AT =
            Instant.parse("2026-01-02T10:00:00.123456Z");
    private static final Instant UPDATED_AT =
            Instant.parse("2026-01-03T10:00:00.123456Z");
    private static final LocalDate EVENT_DATE =
            LocalDate.of(2024, 5, 20);

    @Test
    void shouldDeleteMemoryForOwnerEvenWhenNotAuthor() {

        TestContext context = testContext(
                existingMemory(AUTHOR_ID),
                participant(StoryRole.OWNER)
        );

        context.service().deleteMemory(command());

        assertThat(context.memoryRepository().receivedFindMemoryId())
                .isEqualTo(MEMORY_ID);
        assertThat(context.storyParticipantRepository().receivedStoryId())
                .isEqualTo(STORY_ID);
        assertThat(context.storyParticipantRepository().receivedUserId())
                .isEqualTo(USER_ID);
        assertThat(context.memoryRepository().receivedDeleteMemoryId())
                .isEqualTo(MEMORY_ID);
        assertThat(context.memoryRepository().deleteCallCount())
                .isEqualTo(1);
        assertThat(context.calls()).containsExactly(
                "find Memory for update",
                "find StoryParticipant",
                "delete Memory"
        );
    }

    @Test
    void shouldDeleteMemoryForCoOwnerEvenWhenNotAuthor() {

        TestContext context = testContext(
                existingMemory(AUTHOR_ID),
                participant(StoryRole.CO_OWNER)
        );

        context.service().deleteMemory(command());

        assertThat(context.memoryRepository().deleteCallCount())
                .isEqualTo(1);
    }

    @ParameterizedTest
    @EnumSource(value = StoryRole.class, names = {"EDITOR", "VIEWER"})
    void shouldDeleteOwnMemoryForAuthorRoles(StoryRole role) {

        TestContext context = testContext(
                existingMemory(USER_ID),
                participant(role)
        );

        context.service().deleteMemory(command());

        assertThat(context.memoryRepository().deleteCallCount())
                .isEqualTo(1);
    }

    @ParameterizedTest
    @EnumSource(value = StoryRole.class, names = {"EDITOR", "VIEWER"})
    void shouldDenyNonAuthorEditorAndViewer(StoryRole role) {

        TestContext context = testContext(
                existingMemory(AUTHOR_ID),
                participant(role)
        );

        assertMemoryUnavailable(() -> context.service().deleteMemory(
                command()
        ));

        assertThat(context.memoryRepository().deleteCallCount()).isZero();
        assertThat(context.calls()).containsExactly(
                "find Memory for update",
                "find StoryParticipant"
        );
    }

    @Test
    void shouldThrowMemoryUnavailableWhenMemoryIsMissing() {

        TestContext context = testContext(
                Optional.empty(),
                participant(StoryRole.OWNER)
        );

        assertMemoryUnavailable(() -> context.service().deleteMemory(
                command()
        ));

        assertThat(context.storyParticipantRepository().findCallCount())
                .isZero();
        assertThat(context.memoryRepository().deleteCallCount()).isZero();
        assertThat(context.calls()).containsExactly("find Memory for update");
    }

    @Test
    void shouldThrowMemoryUnavailableWhenMembershipIsMissing() {

        TestContext context = testContext(
                existingMemory(AUTHOR_ID),
                Optional.empty()
        );

        assertMemoryUnavailable(() -> context.service().deleteMemory(
                command()
        ));

        assertThat(context.memoryRepository().deleteCallCount()).isZero();
        assertThat(context.calls()).containsExactly(
                "find Memory for update",
                "find StoryParticipant"
        );
    }

    @Test
    void shouldDenyAuthorWithoutMembership() {

        TestContext context = testContext(
                existingMemory(USER_ID),
                Optional.empty()
        );

        assertMemoryUnavailable(() -> context.service().deleteMemory(
                command()
        ));

        assertThat(context.memoryRepository().deleteCallCount()).isZero();
    }

    @Test
    void shouldDenyParticipantOfAnotherStory() {

        TestContext context = testContext(
                existingMemory(AUTHOR_ID),
                Optional.empty()
        );
        context.storyParticipantRepository().participantInAnotherStory(
                new StoryParticipant(
                        OTHER_STORY_ID,
                        USER_ID,
                        StoryRole.OWNER,
                        JOINED_AT
                )
        );

        assertMemoryUnavailable(() -> context.service().deleteMemory(
                command()
        ));

        assertThat(context.storyParticipantRepository().receivedStoryId())
                .isEqualTo(STORY_ID);
        assertThat(context.memoryRepository().deleteCallCount()).isZero();
    }

    @Test
    void shouldThrowInvariantFailureWhenDeleteAffectsNoRowsAfterLock() {

        TestContext context = testContext(
                existingMemory(AUTHOR_ID),
                participant(StoryRole.OWNER)
        );
        context.memoryRepository().returnDeleteResult(false);

        assertThatThrownBy(() -> context.service().deleteMemory(command()))
                .isInstanceOf(IllegalStateException.class)
                .hasMessage("Memory delete affected no rows after locked lookup")
                .isNotInstanceOf(MemoryDeletionUnavailableException.class);
    }

    @Test
    void shouldPropagateLockedLookupFailure() {

        RuntimeException failure = new RuntimeException("lock failed");
        TestContext context = testContext(
                existingMemory(AUTHOR_ID),
                participant(StoryRole.OWNER)
        );
        context.memoryRepository().failOnFindByIdForUpdate(failure);

        assertThatThrownBy(() -> context.service().deleteMemory(command()))
                .isSameAs(failure);
        assertThat(context.storyParticipantRepository().findCallCount())
                .isZero();
        assertThat(context.memoryRepository().deleteCallCount()).isZero();
    }

    @Test
    void shouldPropagateMembershipLookupFailure() {

        RuntimeException failure = new RuntimeException("membership failed");
        TestContext context = testContext(
                existingMemory(AUTHOR_ID),
                participant(StoryRole.OWNER)
        );
        context.storyParticipantRepository().failOnFind(failure);

        assertThatThrownBy(() -> context.service().deleteMemory(command()))
                .isSameAs(failure);
        assertThat(context.memoryRepository().deleteCallCount()).isZero();
    }

    @Test
    void shouldPropagateDeleteFailure() {

        RuntimeException failure = new RuntimeException("delete failed");
        TestContext context = testContext(
                existingMemory(AUTHOR_ID),
                participant(StoryRole.OWNER)
        );
        context.memoryRepository().failOnDelete(failure);

        assertThatThrownBy(() -> context.service().deleteMemory(command()))
                .isSameAs(failure)
                .isNotInstanceOf(MemoryDeletionUnavailableException.class);
    }

    @Test
    void shouldRejectNullMemoryRepositoryDependency() {

        StoryParticipantRepository storyParticipantRepository = testContext(
                existingMemory(AUTHOR_ID),
                participant(StoryRole.OWNER)
        ).storyParticipantRepository();

        assertThatThrownBy(() -> new TransactionalDeleteMemoryService(
                null,
                storyParticipantRepository
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("memoryRepository must not be null");
    }

    @Test
    void shouldRejectNullStoryParticipantRepositoryDependency() {

        MemoryRepository memoryRepository = testContext(
                existingMemory(AUTHOR_ID),
                participant(StoryRole.OWNER)
        ).memoryRepository();

        assertThatThrownBy(() -> new TransactionalDeleteMemoryService(
                memoryRepository,
                null
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("storyParticipantRepository must not be null");
    }

    @Test
    void shouldRejectNullCommandBeforeInteractions() {

        TestContext context = testContext(
                existingMemory(AUTHOR_ID),
                participant(StoryRole.OWNER)
        );

        assertThatThrownBy(() -> context.service().deleteMemory(null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("command must not be null");

        assertThat(context.memoryRepository().findForUpdateCallCount())
                .isZero();
        assertThat(context.storyParticipantRepository().findCallCount())
                .isZero();
        assertThat(context.memoryRepository().deleteCallCount()).isZero();
    }

    @Test
    void shouldDeclareTransactionalBoundary() throws Exception {

        Method method = TransactionalDeleteMemoryService.class.getMethod(
                "deleteMemory",
                DeleteMemoryCommand.class
        );

        assertThat(method.isAnnotationPresent(Transactional.class)).isTrue();
    }

    private static TestContext testContext(
            Memory memory,
            Optional<StoryParticipant> participant
    ) {
        return testContext(Optional.of(memory), participant);
    }

    private static TestContext testContext(
            Optional<Memory> memory,
            Optional<StoryParticipant> participant
    ) {
        List<String> calls = new ArrayList<>();
        FakeMemoryRepository memoryRepository =
                new FakeMemoryRepository(memory, calls);
        FakeStoryParticipantRepository storyParticipantRepository =
                new FakeStoryParticipantRepository(participant, calls);

        return new TestContext(
                new TransactionalDeleteMemoryService(
                        memoryRepository,
                        storyParticipantRepository
                ),
                memoryRepository,
                storyParticipantRepository,
                calls
        );
    }

    private static Optional<StoryParticipant> participant(StoryRole role) {
        return Optional.of(new StoryParticipant(
                STORY_ID,
                USER_ID,
                role,
                JOINED_AT
        ));
    }

    private static DeleteMemoryCommand command() {
        return new DeleteMemoryCommand(
                new AuthenticatedUser(USER_ID),
                MEMORY_ID
        );
    }

    private static Memory existingMemory(UUID createdBy) {
        return new Memory(
                MEMORY_ID,
                STORY_ID,
                createdBy,
                "First trip",
                "A spring walk",
                "Tbilisi",
                41.715137,
                44.827096,
                EVENT_DATE,
                CREATED_AT,
                UPDATED_AT
        );
    }

    private static void assertMemoryUnavailable(ThrowingAction action) {
        assertThatThrownBy(action::run)
                .isInstanceOf(MemoryDeletionUnavailableException.class)
                .hasMessage("Memory could not be deleted");
    }

    private record TestContext(

            TransactionalDeleteMemoryService service,

            FakeMemoryRepository memoryRepository,

            FakeStoryParticipantRepository storyParticipantRepository,

            List<String> calls

    ) {
    }

    private static final class FakeMemoryRepository
            implements MemoryRepository {

        private final Optional<Memory> memory;
        private final List<String> calls;
        private UUID receivedFindMemoryId;
        private UUID receivedDeleteMemoryId;
        private boolean deleteResult = true;
        private int findForUpdateCallCount;
        private int deleteCallCount;
        private RuntimeException findForUpdateFailure;
        private RuntimeException deleteFailure;

        private FakeMemoryRepository(
                Optional<Memory> memory,
                List<String> calls
        ) {
            this.memory = memory;
            this.calls = calls;
        }

        @Override
        public Optional<Memory> findById(UUID id) {
            throw new UnsupportedOperationException();
        }

        @Override
        public Optional<Memory> findByIdForUpdate(UUID id) {
            calls.add("find Memory for update");
            findForUpdateCallCount++;
            receivedFindMemoryId = id;

            if (findForUpdateFailure != null) {
                throw findForUpdateFailure;
            }

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
            calls.add("delete Memory");
            deleteCallCount++;
            receivedDeleteMemoryId = id;

            if (deleteFailure != null) {
                throw deleteFailure;
            }

            return deleteResult;
        }

        private UUID receivedFindMemoryId() {
            return receivedFindMemoryId;
        }

        private UUID receivedDeleteMemoryId() {
            return receivedDeleteMemoryId;
        }

        private int findForUpdateCallCount() {
            return findForUpdateCallCount;
        }

        private int deleteCallCount() {
            return deleteCallCount;
        }

        private void returnDeleteResult(boolean deleteResult) {
            this.deleteResult = deleteResult;
        }

        private void failOnFindByIdForUpdate(RuntimeException failure) {
            findForUpdateFailure = failure;
        }

        private void failOnDelete(RuntimeException failure) {
            deleteFailure = failure;
        }
    }

    private static final class FakeStoryParticipantRepository
            implements StoryParticipantRepository {

        private final Optional<StoryParticipant> participant;
        private final List<String> calls;
        private StoryParticipant anotherStoryParticipant;
        private UUID receivedStoryId;
        private UUID receivedUserId;
        private int findCallCount;
        private RuntimeException failure;

        private FakeStoryParticipantRepository(
                Optional<StoryParticipant> participant,
                List<String> calls
        ) {
            this.participant = participant;
            this.calls = calls;
        }

        @Override
        public Optional<StoryParticipant> find(UUID storyId, UUID userId) {
            calls.add("find StoryParticipant");
            findCallCount++;
            receivedStoryId = storyId;
            receivedUserId = userId;

            if (failure != null) {
                throw failure;
            }

            if (
                    anotherStoryParticipant != null
                            && anotherStoryParticipant.storyId().equals(storyId)
                            && anotherStoryParticipant.userId().equals(userId)
            ) {
                return Optional.of(anotherStoryParticipant);
            }

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

        private UUID receivedStoryId() {
            return receivedStoryId;
        }

        private UUID receivedUserId() {
            return receivedUserId;
        }

        private int findCallCount() {
            return findCallCount;
        }

        private void participantInAnotherStory(StoryParticipant participant) {
            anotherStoryParticipant = participant;
        }

        private void failOnFind(RuntimeException failure) {
            this.failure = failure;
        }
    }

    @FunctionalInterface
    private interface ThrowingAction {

        void run();
    }
}
