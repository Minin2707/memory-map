package memory_map.backend.story.application;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.story.domain.Story;
import memory_map.backend.story.repository.StoryRepository;
import memory_map.backend.storyparticipant.domain.StoryParticipant;
import memory_map.backend.storyparticipant.domain.StoryRole;
import memory_map.backend.storyparticipant.repository.StoryParticipantRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;
import org.springframework.transaction.annotation.Transactional;

import java.lang.reflect.Method;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class TransactionalLeaveStoryServiceTest {

    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000011");
    private static final Instant JOINED_AT =
            Instant.parse("2026-01-01T10:00:00.123456Z");

    @Test
    void shouldRejectNullStoryRepositoryDependency() {

        StoryParticipantRepository participantRepository =
                testContext(StoryRole.CO_OWNER)
                        .storyParticipantRepository();

        assertThatThrownBy(() -> new TransactionalLeaveStoryService(
                null,
                participantRepository
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("storyRepository must not be null");
    }

    @Test
    void shouldRejectNullStoryParticipantRepositoryDependency() {

        StoryRepository storyRepository =
                testContext(StoryRole.CO_OWNER)
                        .storyRepository();

        assertThatThrownBy(() -> new TransactionalLeaveStoryService(
                storyRepository,
                null
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("storyParticipantRepository must not be null");
    }

    @Test
    void shouldRejectNullCommand() {

        assertThatThrownBy(() -> testContext(StoryRole.CO_OWNER)
                .service()
                .leaveStory(null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("command must not be null");
    }

    @Test
    void shouldDeclareTransactionalBoundary() throws Exception {

        Method method = TransactionalLeaveStoryService.class.getMethod(
                "leaveStory",
                LeaveStoryCommand.class
        );

        assertThat(method.isAnnotationPresent(Transactional.class)).isTrue();
    }

    @Test
    void shouldThrowStoryNotFoundWhenStoryLockReportsMissing() {

        TestContext context = testContext(StoryRole.CO_OWNER);
        context.storyRepository().lockResult(false);

        assertStoryNotFound(() -> context.service().leaveStory(command()));

        assertThat(context.storyRepository().receivedLockStoryId())
                .isEqualTo(STORY_ID);
        assertThat(context.storyParticipantRepository().findCallCount())
                .isZero();
        assertThat(context.storyParticipantRepository().countOwnersCallCount())
                .isZero();
        assertThat(context.storyParticipantRepository().deleteCallCount())
                .isZero();
    }

    @Test
    void shouldThrowStoryNotFoundWhenRequesterIsNotParticipant() {

        TestContext context = testContext(Optional.empty());

        assertStoryNotFound(() -> context.service().leaveStory(command()));

        assertThat(context.storyParticipantRepository().receivedFindStoryId())
                .isEqualTo(STORY_ID);
        assertThat(context.storyParticipantRepository().receivedFindUserId())
                .isEqualTo(USER_ID);
        assertThat(context.storyParticipantRepository().countOwnersCallCount())
                .isZero();
        assertThat(context.storyParticipantRepository().deleteCallCount())
                .isZero();
    }

    @ParameterizedTest
    @EnumSource(value = StoryRole.class, names = {"CO_OWNER", "EDITOR", "VIEWER"})
    void shouldDeleteOwnMembershipForNonOwnerRoles(StoryRole role) {

        TestContext context = testContext(role);

        context.service().leaveStory(command());

        assertThat(context.storyParticipantRepository().receivedDeleteStoryId())
                .isEqualTo(STORY_ID);
        assertThat(context.storyParticipantRepository().receivedDeleteUserId())
                .isEqualTo(USER_ID);
        assertThat(context.storyParticipantRepository().countOwnersCallCount())
                .isZero();
    }

    @Test
    void shouldRejectLastOwnerLeave() {

        TestContext context = testContext(StoryRole.OWNER);
        context.storyParticipantRepository().ownerCount(1);

        assertThatThrownBy(() -> context.service().leaveStory(command()))
                .isInstanceOf(LastStoryOwnerCannotLeaveException.class)
                .hasMessage("The last owner cannot leave the story");

        assertThat(context.storyParticipantRepository().deleteCallCount())
                .isZero();
    }

    @Test
    void shouldDeleteOwnerWhenAnotherOwnerExists() {

        TestContext context = testContext(StoryRole.OWNER);
        context.storyParticipantRepository().ownerCount(2);

        context.service().leaveStory(command());

        assertThat(context.storyParticipantRepository().receivedCountStoryId())
                .isEqualTo(STORY_ID);
        assertThat(context.storyParticipantRepository().receivedDeleteStoryId())
                .isEqualTo(STORY_ID);
        assertThat(context.storyParticipantRepository().receivedDeleteUserId())
                .isEqualTo(USER_ID);
    }

    @Test
    void shouldTreatZeroOwnerCountAsCorruptedState() {

        TestContext context = testContext(StoryRole.OWNER);
        context.storyParticipantRepository().ownerCount(0);

        assertThatThrownBy(() -> context.service().leaveStory(command()))
                .isInstanceOf(IllegalStateException.class)
                .hasMessage("Story owner participant count is inconsistent");

        assertThat(context.storyParticipantRepository().deleteCallCount())
                .isZero();
    }

    @Test
    void shouldUseAuthenticatedUserAsOnlyDeleteTarget() {

        TestContext context = testContext(StoryRole.EDITOR);

        context.service().leaveStory(command());

        assertThat(context.storyParticipantRepository().receivedFindUserId())
                .isEqualTo(USER_ID);
        assertThat(context.storyParticipantRepository().receivedDeleteUserId())
                .isEqualTo(USER_ID);
    }

    @Test
    void shouldUseExpectedInteractionOrderForNonOwner() {

        TestContext context = testContext(StoryRole.VIEWER);

        context.service().leaveStory(command());

        assertThat(context.calls()).containsExactly(
                "lock Story",
                "find StoryParticipant",
                "delete StoryParticipant"
        );
    }

    @Test
    void shouldUseExpectedInteractionOrderForOwner() {

        TestContext context = testContext(StoryRole.OWNER);
        context.storyParticipantRepository().ownerCount(2);

        context.service().leaveStory(command());

        assertThat(context.calls()).containsExactly(
                "lock Story",
                "find StoryParticipant",
                "count OWNER StoryParticipant",
                "delete StoryParticipant"
        );
    }

    @Test
    void shouldPropagateLockRepositoryFailure() {

        RuntimeException failure = new RuntimeException("lock failed");
        TestContext context = testContext(StoryRole.CO_OWNER);
        context.storyRepository().failOnLock(failure);

        assertThatThrownBy(() -> context.service().leaveStory(command()))
                .isSameAs(failure);

        assertThat(context.storyParticipantRepository().findCallCount())
                .isZero();
    }

    @Test
    void shouldPropagateParticipantLookupFailure() {

        RuntimeException failure = new RuntimeException("lookup failed");
        TestContext context = testContext(StoryRole.CO_OWNER);
        context.storyParticipantRepository().failOnFind(failure);

        assertThatThrownBy(() -> context.service().leaveStory(command()))
                .isSameAs(failure);

        assertThat(context.storyParticipantRepository().deleteCallCount())
                .isZero();
    }

    @Test
    void shouldPropagateOwnerCountFailure() {

        RuntimeException failure = new RuntimeException("count failed");
        TestContext context = testContext(StoryRole.OWNER);
        context.storyParticipantRepository().failOnCountOwners(failure);

        assertThatThrownBy(() -> context.service().leaveStory(command()))
                .isSameAs(failure);

        assertThat(context.storyParticipantRepository().deleteCallCount())
                .isZero();
    }

    @Test
    void shouldPropagateDeleteFailure() {

        RuntimeException failure = new RuntimeException("delete failed");
        TestContext context = testContext(StoryRole.CO_OWNER);
        context.storyParticipantRepository().failOnDelete(failure);

        assertThatThrownBy(() -> context.service().leaveStory(command()))
                .isSameAs(failure);
    }

    private static void assertStoryNotFound(ThrowingAction action) {
        assertThatThrownBy(action::run)
                .isInstanceOf(StoryNotFoundException.class)
                .hasMessage("Story was not found");
    }

    private static TestContext testContext(StoryRole role) {
        return testContext(Optional.of(participant(role)));
    }

    private static TestContext testContext(
            Optional<StoryParticipant> participant
    ) {
        List<String> calls = new ArrayList<>();
        FakeStoryRepository storyRepository =
                new FakeStoryRepository(calls);
        FakeStoryParticipantRepository storyParticipantRepository =
                new FakeStoryParticipantRepository(calls, participant);

        return new TestContext(
                new TransactionalLeaveStoryService(
                        storyRepository,
                        storyParticipantRepository
                ),
                storyRepository,
                storyParticipantRepository,
                calls
        );
    }

    private static LeaveStoryCommand command() {
        return new LeaveStoryCommand(
                new AuthenticatedUser(USER_ID),
                STORY_ID
        );
    }

    private static StoryParticipant participant(StoryRole role) {
        return new StoryParticipant(
                STORY_ID,
                USER_ID,
                role,
                JOINED_AT
        );
    }

    private record TestContext(

            TransactionalLeaveStoryService service,

            FakeStoryRepository storyRepository,

            FakeStoryParticipantRepository storyParticipantRepository,

            List<String> calls

    ) {
    }

    private static final class FakeStoryRepository
            implements StoryRepository {

        private final List<String> calls;
        private boolean lockResult = true;
        private UUID receivedLockStoryId;
        private RuntimeException lockFailure;

        private FakeStoryRepository(List<String> calls) {
            this.calls = calls;
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
        public boolean lockById(UUID id) {
            calls.add("lock Story");
            receivedLockStoryId = id;

            if (lockFailure != null) {
                throw lockFailure;
            }

            return lockResult;
        }

        @Override
        public List<Story> findByOwnerId(UUID ownerId) {
            throw new UnsupportedOperationException();
        }

        private void lockResult(boolean lockResult) {
            this.lockResult = lockResult;
        }

        private UUID receivedLockStoryId() {
            return receivedLockStoryId;
        }

        private void failOnLock(RuntimeException failure) {
            lockFailure = failure;
        }
    }

    private static final class FakeStoryParticipantRepository
            implements StoryParticipantRepository {

        private final List<String> calls;
        private final Optional<StoryParticipant> participant;
        private long ownerCount = 2;
        private UUID receivedFindStoryId;
        private UUID receivedFindUserId;
        private UUID receivedCountStoryId;
        private UUID receivedDeleteStoryId;
        private UUID receivedDeleteUserId;
        private int findCallCount;
        private int countOwnersCallCount;
        private int deleteCallCount;
        private RuntimeException findFailure;
        private RuntimeException countOwnersFailure;
        private RuntimeException deleteFailure;

        private FakeStoryParticipantRepository(
                List<String> calls,
                Optional<StoryParticipant> participant
        ) {
            this.calls = calls;
            this.participant = participant;
        }

        @Override
        public Optional<StoryParticipant> find(UUID storyId, UUID userId) {
            calls.add("find StoryParticipant");
            findCallCount++;
            receivedFindStoryId = storyId;
            receivedFindUserId = userId;

            if (findFailure != null) {
                throw findFailure;
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
            calls.add("count OWNER StoryParticipant");
            countOwnersCallCount++;
            receivedCountStoryId = storyId;

            if (countOwnersFailure != null) {
                throw countOwnersFailure;
            }

            return ownerCount;
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
            calls.add("delete StoryParticipant");
            deleteCallCount++;
            receivedDeleteStoryId = storyId;
            receivedDeleteUserId = userId;

            if (deleteFailure != null) {
                throw deleteFailure;
            }
        }

        private void ownerCount(long ownerCount) {
            this.ownerCount = ownerCount;
        }

        private UUID receivedFindStoryId() {
            return receivedFindStoryId;
        }

        private UUID receivedFindUserId() {
            return receivedFindUserId;
        }

        private UUID receivedCountStoryId() {
            return receivedCountStoryId;
        }

        private UUID receivedDeleteStoryId() {
            return receivedDeleteStoryId;
        }

        private UUID receivedDeleteUserId() {
            return receivedDeleteUserId;
        }

        private int findCallCount() {
            return findCallCount;
        }

        private int countOwnersCallCount() {
            return countOwnersCallCount;
        }

        private int deleteCallCount() {
            return deleteCallCount;
        }

        private void failOnFind(RuntimeException failure) {
            findFailure = failure;
        }

        private void failOnCountOwners(RuntimeException failure) {
            countOwnersFailure = failure;
        }

        private void failOnDelete(RuntimeException failure) {
            deleteFailure = failure;
        }
    }

    @FunctionalInterface
    private interface ThrowingAction {

        void run();
    }
}
