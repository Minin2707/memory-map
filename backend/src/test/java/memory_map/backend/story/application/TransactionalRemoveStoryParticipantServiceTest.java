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

class TransactionalRemoveStoryParticipantServiceTest {

    private static final UUID ACTOR_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID TARGET_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000002");
    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000011");
    private static final Instant JOINED_AT =
            Instant.parse("2026-01-01T10:00:00.123456Z");

    @Test
    void shouldRejectNullStoryRepositoryDependency() {

        StoryParticipantRepository participantRepository =
                testContext().storyParticipantRepository();

        assertThatThrownBy(() ->
                new TransactionalRemoveStoryParticipantService(
                        null,
                        participantRepository
                ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("storyRepository must not be null");
    }

    @Test
    void shouldRejectNullStoryParticipantRepositoryDependency() {

        StoryRepository storyRepository = testContext().storyRepository();

        assertThatThrownBy(() ->
                new TransactionalRemoveStoryParticipantService(
                        storyRepository,
                        null
                ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("storyParticipantRepository must not be null");
    }

    @Test
    void shouldRejectNullCommand() {

        assertThatThrownBy(() ->
                testContext().service().removeParticipant(null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("command must not be null");
    }

    @Test
    void shouldDeclareTransactionalBoundary() throws Exception {

        Method method = TransactionalRemoveStoryParticipantService.class
                .getMethod(
                        "removeParticipant",
                        RemoveStoryParticipantCommand.class
                );

        assertThat(method.isAnnotationPresent(Transactional.class)).isTrue();
    }

    @Test
    void shouldThrowStoryNotFoundWhenStoryLockReportsMissing() {

        TestContext context = testContext();
        context.storyRepository().lockResult(false);

        assertStoryNotFound(() ->
                context.service().removeParticipant(command()));

        assertThat(context.storyRepository().receivedLockStoryId())
                .isEqualTo(STORY_ID);
        assertThat(context.storyParticipantRepository().findCallCount())
                .isZero();
        assertThat(context.storyParticipantRepository().deleteCallCount())
                .isZero();
        assertThat(context.storyParticipantRepository().countOwnersCallCount())
                .isZero();
    }

    @Test
    void shouldThrowStoryNotFoundWhenActorMembershipIsMissing() {

        TestContext context = testContext(
                Optional.empty(),
                Optional.of(participant(TARGET_ID, StoryRole.VIEWER))
        );

        assertStoryNotFound(() ->
                context.service().removeParticipant(command()));

        assertThat(context.storyParticipantRepository().receivedFindUserIds())
                .containsExactly(ACTOR_ID);
        assertThat(context.storyParticipantRepository().deleteCallCount())
                .isZero();
    }

    @ParameterizedTest
    @EnumSource(value = StoryRole.class, names = {"CO_OWNER", "EDITOR", "VIEWER"})
    void shouldThrowStoryNotFoundForNonOwnerActor(StoryRole role) {

        TestContext context = testContext(
                Optional.of(participant(ACTOR_ID, role)),
                Optional.of(participant(TARGET_ID, StoryRole.VIEWER))
        );

        assertStoryNotFound(() ->
                context.service().removeParticipant(command()));

        assertThat(context.storyParticipantRepository().receivedFindUserIds())
                .containsExactly(ACTOR_ID);
        assertThat(context.storyParticipantRepository().deleteCallCount())
                .isZero();
    }

    @Test
    void shouldRejectSelfTargetOnlyAfterConfirmedOwnerActor() {

        TestContext context = testContext(
                Optional.of(participant(ACTOR_ID, StoryRole.OWNER)),
                Optional.of(participant(TARGET_ID, StoryRole.VIEWER))
        );

        assertThatThrownBy(() -> context.service()
                .removeParticipant(command(ACTOR_ID)))
                .isInstanceOf(ParticipantCannotRemoveSelfException.class)
                .hasMessage("Use the leave story operation to remove yourself");

        assertThat(context.storyParticipantRepository().receivedFindUserIds())
                .containsExactly(ACTOR_ID);
        assertThat(context.storyParticipantRepository().deleteCallCount())
                .isZero();
    }

    @ParameterizedTest
    @EnumSource(value = StoryRole.class, names = {"CO_OWNER", "EDITOR", "VIEWER"})
    void shouldReturnSafeNotFoundForUnauthorizedSelfTarget(StoryRole role) {

        TestContext context = testContext(
                Optional.of(participant(ACTOR_ID, role)),
                Optional.empty()
        );

        assertStoryNotFound(() -> context.service()
                .removeParticipant(command(ACTOR_ID)));

        assertThat(context.storyParticipantRepository().receivedFindUserIds())
                .containsExactly(ACTOR_ID);
        assertThat(context.storyParticipantRepository().deleteCallCount())
                .isZero();
    }

    @Test
    void shouldThrowStoryNotFoundWhenTargetMembershipIsMissing() {

        TestContext context = testContext(
                Optional.of(participant(ACTOR_ID, StoryRole.OWNER)),
                Optional.empty()
        );

        assertStoryNotFound(() ->
                context.service().removeParticipant(command()));

        assertThat(context.storyParticipantRepository().receivedFindUserIds())
                .containsExactly(ACTOR_ID, TARGET_ID);
        assertThat(context.storyParticipantRepository().deleteCallCount())
                .isZero();
    }

    @Test
    void shouldRejectOwnerTarget() {

        TestContext context = testContext(
                Optional.of(participant(ACTOR_ID, StoryRole.OWNER)),
                Optional.of(participant(TARGET_ID, StoryRole.OWNER))
        );

        assertThatThrownBy(() ->
                context.service().removeParticipant(command()))
                .isInstanceOf(StoryOwnerCannotBeRemovedException.class)
                .hasMessage("A story owner cannot be removed");

        assertThat(context.storyParticipantRepository().deleteCallCount())
                .isZero();
    }

    @ParameterizedTest
    @EnumSource(value = StoryRole.class, names = {"CO_OWNER", "EDITOR", "VIEWER"})
    void shouldAllowOwnerToRemoveNonOwnerTarget(StoryRole targetRole) {

        TestContext context = testContext(
                Optional.of(participant(ACTOR_ID, StoryRole.OWNER)),
                Optional.of(participant(TARGET_ID, targetRole))
        );

        context.service().removeParticipant(command());

        assertThat(context.storyParticipantRepository().receivedDeleteStoryId())
                .isEqualTo(STORY_ID);
        assertThat(context.storyParticipantRepository().receivedDeleteUserId())
                .isEqualTo(TARGET_ID);
        assertThat(context.storyParticipantRepository().receivedDeleteUserId())
                .isNotEqualTo(ACTOR_ID);
        assertThat(context.storyParticipantRepository().countOwnersCallCount())
                .isZero();
    }

    @Test
    void shouldForwardExactIdentifiersAndUseExpectedSuccessOrder() {

        TestContext context = testContext();

        context.service().removeParticipant(command());

        assertThat(context.storyRepository().receivedLockStoryId())
                .isEqualTo(STORY_ID);
        assertThat(context.storyParticipantRepository().receivedFindStoryIds())
                .containsExactly(STORY_ID, STORY_ID);
        assertThat(context.storyParticipantRepository().receivedFindUserIds())
                .containsExactly(ACTOR_ID, TARGET_ID);
        assertThat(context.calls()).containsExactly(
                "lock Story",
                "find actor StoryParticipant",
                "find target StoryParticipant",
                "delete target StoryParticipant"
        );
    }

    @Test
    void shouldPropagateLockRepositoryFailure() {

        RuntimeException failure = new RuntimeException("lock failed");
        TestContext context = testContext();
        context.storyRepository().failOnLock(failure);

        assertThatThrownBy(() ->
                context.service().removeParticipant(command()))
                .isSameAs(failure);

        assertThat(context.storyParticipantRepository().findCallCount())
                .isZero();
    }

    @Test
    void shouldPropagateActorLookupFailure() {

        RuntimeException failure = new RuntimeException("actor lookup failed");
        TestContext context = testContext();
        context.storyParticipantRepository().failOnActorFind(failure);

        assertThatThrownBy(() ->
                context.service().removeParticipant(command()))
                .isSameAs(failure);

        assertThat(context.storyParticipantRepository().deleteCallCount())
                .isZero();
    }

    @Test
    void shouldPropagateTargetLookupFailure() {

        RuntimeException failure = new RuntimeException("target lookup failed");
        TestContext context = testContext();
        context.storyParticipantRepository().failOnTargetFind(failure);

        assertThatThrownBy(() ->
                context.service().removeParticipant(command()))
                .isSameAs(failure);

        assertThat(context.storyParticipantRepository().deleteCallCount())
                .isZero();
    }

    @Test
    void shouldPropagateDeleteFailure() {

        RuntimeException failure = new RuntimeException("delete failed");
        TestContext context = testContext();
        context.storyParticipantRepository().failOnDelete(failure);

        assertThatThrownBy(() ->
                context.service().removeParticipant(command()))
                .isSameAs(failure);
    }

    private static void assertStoryNotFound(ThrowingAction action) {
        assertThatThrownBy(action::run)
                .isInstanceOf(StoryNotFoundException.class)
                .hasMessage("Story was not found");
    }

    private static TestContext testContext() {
        return testContext(
                Optional.of(participant(ACTOR_ID, StoryRole.OWNER)),
                Optional.of(participant(TARGET_ID, StoryRole.VIEWER))
        );
    }

    private static TestContext testContext(
            Optional<StoryParticipant> actor,
            Optional<StoryParticipant> target
    ) {
        List<String> calls = new ArrayList<>();
        FakeStoryRepository storyRepository =
                new FakeStoryRepository(calls);
        FakeStoryParticipantRepository storyParticipantRepository =
                new FakeStoryParticipantRepository(calls, actor, target);

        return new TestContext(
                new TransactionalRemoveStoryParticipantService(
                        storyRepository,
                        storyParticipantRepository
                ),
                storyRepository,
                storyParticipantRepository,
                calls
        );
    }

    private static RemoveStoryParticipantCommand command() {
        return command(TARGET_ID);
    }

    private static RemoveStoryParticipantCommand command(UUID targetUserId) {
        return new RemoveStoryParticipantCommand(
                new AuthenticatedUser(ACTOR_ID),
                STORY_ID,
                targetUserId
        );
    }

    private static StoryParticipant participant(UUID userId, StoryRole role) {
        return new StoryParticipant(
                STORY_ID,
                userId,
                role,
                JOINED_AT
        );
    }

    private record TestContext(

            TransactionalRemoveStoryParticipantService service,

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
        private final Optional<StoryParticipant> actor;
        private final Optional<StoryParticipant> target;
        private final List<UUID> receivedFindStoryIds = new ArrayList<>();
        private final List<UUID> receivedFindUserIds = new ArrayList<>();
        private UUID receivedDeleteStoryId;
        private UUID receivedDeleteUserId;
        private int countOwnersCallCount;
        private int deleteCallCount;
        private RuntimeException actorFindFailure;
        private RuntimeException targetFindFailure;
        private RuntimeException deleteFailure;

        private FakeStoryParticipantRepository(
                List<String> calls,
                Optional<StoryParticipant> actor,
                Optional<StoryParticipant> target
        ) {
            this.calls = calls;
            this.actor = actor;
            this.target = target;
        }

        @Override
        public Optional<StoryParticipant> find(UUID storyId, UUID userId) {
            receivedFindStoryIds.add(storyId);
            receivedFindUserIds.add(userId);

            if (userId.equals(ACTOR_ID)) {
                calls.add("find actor StoryParticipant");

                if (actorFindFailure != null) {
                    throw actorFindFailure;
                }

                return actor;
            }

            calls.add("find target StoryParticipant");

            if (targetFindFailure != null) {
                throw targetFindFailure;
            }

            return target;
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
            countOwnersCallCount++;
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
            calls.add("delete target StoryParticipant");
            deleteCallCount++;
            receivedDeleteStoryId = storyId;
            receivedDeleteUserId = userId;

            if (deleteFailure != null) {
                throw deleteFailure;
            }
        }

        private List<UUID> receivedFindStoryIds() {
            return receivedFindStoryIds;
        }

        private List<UUID> receivedFindUserIds() {
            return receivedFindUserIds;
        }

        private UUID receivedDeleteStoryId() {
            return receivedDeleteStoryId;
        }

        private UUID receivedDeleteUserId() {
            return receivedDeleteUserId;
        }

        private int findCallCount() {
            return receivedFindUserIds.size();
        }

        private int countOwnersCallCount() {
            return countOwnersCallCount;
        }

        private int deleteCallCount() {
            return deleteCallCount;
        }

        private void failOnActorFind(RuntimeException failure) {
            actorFindFailure = failure;
        }

        private void failOnTargetFind(RuntimeException failure) {
            targetFindFailure = failure;
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
