package memory_map.backend.story.application;

import memory_map.backend.IntegrationTest;
import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.story.domain.Story;
import memory_map.backend.story.repository.JdbcStoryRepository;
import memory_map.backend.story.repository.StoryRepository;
import memory_map.backend.storyparticipant.domain.StoryParticipant;
import memory_map.backend.storyparticipant.domain.StoryRole;
import memory_map.backend.storyparticipant.repository.JdbcStoryParticipantRepository;
import memory_map.backend.storyparticipant.repository.StoryParticipantRepository;
import memory_map.backend.user.domain.User;
import memory_map.backend.user.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.context.annotation.Primary;
import org.springframework.jdbc.core.simple.JdbcClient;

import java.time.Instant;
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
import static org.assertj.core.api.Assertions.assertThatThrownBy;

@Import(LeaveStoryUseCaseIntegrationTest.LeaveStoryUseCaseTestConfiguration.class)
class LeaveStoryUseCaseIntegrationTest extends IntegrationTest {

    @Autowired
    private LeaveStoryUseCase leaveStoryUseCase;

    @Autowired
    private StoryRepository storyRepository;

    @Autowired
    private BlockingStoryRepository blockingStoryRepository;

    @Autowired
    private StoryParticipantRepository storyParticipantRepository;

    @Autowired
    private FailingStoryParticipantRepository
            failingStoryParticipantRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private JdbcClient jdbcClient;

    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID OWNER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000002");
    private static final UUID OTHER_OWNER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000003");
    private static final UUID OTHER_USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000004");
    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000011");
    private static final UUID OTHER_STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000012");
    private static final Instant BASE_TIME =
            Instant.parse("2026-01-01T10:00:00.123456Z");
    private static final Instant OTHER_JOINED_AT =
            Instant.parse("2026-01-02T10:00:00.123456Z");
    private static final String CLEAN_DATABASE_SQL = """
        TRUNCATE TABLE users
        RESTART IDENTITY CASCADE
        """;

    @BeforeEach
    void cleanDatabase() {
        blockingStoryRepository.reset();
        failingStoryParticipantRepository.reset();
        jdbcClient.sql(CLEAN_DATABASE_SQL).update();
    }

    @ParameterizedTest
    @EnumSource(value = StoryRole.class, names = {"CO_OWNER", "EDITOR", "VIEWER"})
    void shouldAllowNonOwnerParticipantToLeave(StoryRole role) {

        User owner = saveUser(OWNER_ID);
        User user = saveUser(USER_ID);
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER, BASE_TIME);
        StoryParticipant leavingParticipant = saveParticipant(
                story.id(),
                user.id(),
                role,
                OTHER_JOINED_AT
        );

        leaveStoryUseCase.leaveStory(command(user.id(), story.id()));

        assertThat(storyParticipantRepository.find(story.id(), user.id()))
                .isEmpty();
        assertThat(storyParticipantRepository.find(story.id(), owner.id()))
                .contains(new StoryParticipant(
                        story.id(),
                        owner.id(),
                        StoryRole.OWNER,
                        BASE_TIME
                ));
        assertThat(storyRepository.findById(story.id())).contains(story);
        assertThat(leavingParticipant.role()).isEqualTo(role);
    }

    @Test
    void shouldRejectOnlyOwnerLeaveAndKeepParticipant() {

        User owner = saveUser(OWNER_ID);
        Story story = saveStory(STORY_ID, owner.id());
        StoryParticipant ownerParticipant = saveParticipant(
                story.id(),
                owner.id(),
                StoryRole.OWNER,
                BASE_TIME
        );

        assertThatThrownBy(() ->
                leaveStoryUseCase.leaveStory(command(owner.id(), story.id())))
                .isInstanceOf(LastStoryOwnerCannotLeaveException.class)
                .hasMessage("The last owner cannot leave the story");

        assertThat(storyParticipantRepository.find(story.id(), owner.id()))
                .contains(ownerParticipant);
        assertThat(countOwners(story.id())).isEqualTo(1);
    }

    @Test
    void shouldRejectOwnerLeaveWhenOnlyCoOwnerWouldRemain() {

        User owner = saveUser(OWNER_ID);
        User coOwner = saveUser(USER_ID);
        Story story = saveStory(STORY_ID, owner.id());
        StoryParticipant ownerParticipant = saveParticipant(
                story.id(),
                owner.id(),
                StoryRole.OWNER,
                BASE_TIME
        );
        StoryParticipant coOwnerParticipant = saveParticipant(
                story.id(),
                coOwner.id(),
                StoryRole.CO_OWNER,
                OTHER_JOINED_AT
        );

        assertThatThrownBy(() ->
                leaveStoryUseCase.leaveStory(command(owner.id(), story.id())))
                .isInstanceOf(LastStoryOwnerCannotLeaveException.class);

        assertThat(storyParticipantRepository.find(story.id(), owner.id()))
                .contains(ownerParticipant);
        assertThat(storyParticipantRepository.find(story.id(), coOwner.id()))
                .contains(coOwnerParticipant);
        assertThat(countOwners(story.id())).isEqualTo(1);
    }

    @Test
    void shouldAllowOwnerToLeaveWhenAnotherOwnerExists() {

        User creator = saveUser(OWNER_ID);
        User otherOwner = saveUser(OTHER_OWNER_ID);
        Story story = saveStory(STORY_ID, creator.id());
        saveParticipant(story.id(), creator.id(), StoryRole.OWNER, BASE_TIME);
        StoryParticipant remainingOwner = saveParticipant(
                story.id(),
                otherOwner.id(),
                StoryRole.OWNER,
                OTHER_JOINED_AT
        );

        leaveStoryUseCase.leaveStory(command(creator.id(), story.id()));

        Story persistedStory = storyRepository.findById(story.id())
                .orElseThrow();

        assertThat(storyParticipantRepository.find(story.id(), creator.id()))
                .isEmpty();
        assertThat(storyParticipantRepository.find(
                story.id(),
                otherOwner.id()
        )).contains(remainingOwner);
        assertThat(countOwners(story.id())).isEqualTo(1);
        assertThat(persistedStory).isEqualTo(story);
        assertThat(persistedStory.ownerId()).isEqualTo(creator.id());
    }

    @Test
    void shouldThrowStoryNotFoundForMissingStory() {

        User user = saveUser(USER_ID);

        assertStoryNotFound(() ->
                leaveStoryUseCase.leaveStory(command(user.id(), STORY_ID)));
    }

    @Test
    void shouldThrowSameStoryNotFoundForOutsiderAndMissingStory() {

        User owner = saveUser(OWNER_ID);
        User outsider = saveUser(USER_ID);
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER, BASE_TIME);

        StoryNotFoundException inaccessible = catchStoryNotFound(() ->
                leaveStoryUseCase.leaveStory(command(
                        outsider.id(),
                        story.id()
                )));
        StoryNotFoundException missing = catchStoryNotFound(() ->
                leaveStoryUseCase.leaveStory(command(
                        outsider.id(),
                        OTHER_STORY_ID
                )));

        assertThat(inaccessible.getClass()).isEqualTo(missing.getClass());
        assertThat(inaccessible.getMessage()).isEqualTo(missing.getMessage());
        assertThat(storyParticipantRepository.find(story.id(), owner.id()))
                .isPresent();
    }

    @Test
    void shouldThrowStoryNotFoundForParticipantOfAnotherStory() {

        User owner = saveUser(OWNER_ID);
        User user = saveUser(USER_ID);
        Story story = saveStory(STORY_ID, owner.id());
        Story otherStory = saveStory(OTHER_STORY_ID, owner.id());
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER, BASE_TIME);
        StoryParticipant otherParticipant = saveParticipant(
                otherStory.id(),
                user.id(),
                StoryRole.EDITOR,
                OTHER_JOINED_AT
        );

        assertStoryNotFound(() ->
                leaveStoryUseCase.leaveStory(command(user.id(), story.id())));

        assertThat(storyParticipantRepository.find(
                otherStory.id(),
                user.id()
        )).contains(otherParticipant);
    }

    @Test
    void shouldThrowStoryNotFoundForOwnerIdWithoutMembership() {

        User owner = saveUser(OWNER_ID);
        Story story = saveStory(STORY_ID, owner.id());

        assertStoryNotFound(() ->
                leaveStoryUseCase.leaveStory(command(owner.id(), story.id())));

        assertThat(storyRepository.findById(story.id())).contains(story);
    }

    @Test
    void shouldThrowStoryNotFoundForRepeatedLeave() {

        User owner = saveUser(OWNER_ID);
        User viewer = saveUser(USER_ID);
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER, BASE_TIME);
        saveParticipant(story.id(), viewer.id(), StoryRole.VIEWER, BASE_TIME);

        leaveStoryUseCase.leaveStory(command(viewer.id(), story.id()));

        assertStoryNotFound(() ->
                leaveStoryUseCase.leaveStory(command(viewer.id(), story.id())));
    }

    @Test
    void shouldRollbackParticipantDeleteWhenRepositoryFailsAfterDelete() {

        User owner = saveUser(OWNER_ID);
        User otherOwner = saveUser(OTHER_OWNER_ID);
        Story story = saveStory(STORY_ID, owner.id());
        StoryParticipant leavingOwner = saveParticipant(
                story.id(),
                owner.id(),
                StoryRole.OWNER,
                BASE_TIME
        );
        saveParticipant(
                story.id(),
                otherOwner.id(),
                StoryRole.OWNER,
                OTHER_JOINED_AT
        );
        failingStoryParticipantRepository.failAfterDelete(
                new RuntimeException("participant delete failed")
        );

        assertThatThrownBy(() ->
                leaveStoryUseCase.leaveStory(command(owner.id(), story.id())))
                .isInstanceOf(RuntimeException.class)
                .hasMessage("participant delete failed");

        assertThat(storyParticipantRepository.find(story.id(), owner.id()))
                .contains(leavingOwner);
        assertThat(countOwners(story.id())).isEqualTo(2);
    }

    @Test
    void shouldSerializeConcurrentOwnerLeaves() throws Exception {

        User firstOwner = saveUser(OWNER_ID);
        User secondOwner = saveUser(OTHER_OWNER_ID);
        Story story = saveStory(STORY_ID, firstOwner.id());
        saveParticipant(
                story.id(),
                firstOwner.id(),
                StoryRole.OWNER,
                BASE_TIME
        );
        saveParticipant(
                story.id(),
                secondOwner.id(),
                StoryRole.OWNER,
                OTHER_JOINED_AT
        );
        ExecutorService executor = Executors.newFixedThreadPool(2);
        blockingStoryRepository.blockFirstLock();

        try {
            Future<Void> first = executor.submit(() -> {
                leaveStoryUseCase.leaveStory(command(
                        firstOwner.id(),
                        story.id()
                ));

                return null;
            });

            blockingStoryRepository.awaitFirstLockAcquired();

            Future<Void> second = executor.submit(() -> {
                leaveStoryUseCase.leaveStory(command(
                        secondOwner.id(),
                        story.id()
                ));

                return null;
            });

            blockingStoryRepository.awaitSecondLockAttemptStarted();
            assertThatThrownBy(() -> second.get(250, TimeUnit.MILLISECONDS))
                    .isInstanceOf(TimeoutException.class);

            blockingStoryRepository.releaseFirstTransaction();

            assertThat(first.get(10, TimeUnit.SECONDS)).isNull();
            assertThatThrownBy(() -> second.get(10, TimeUnit.SECONDS))
                    .isInstanceOf(ExecutionException.class)
                    .satisfies(exception -> assertThat(
                            exception.getCause()
                    ).isInstanceOf(
                            LastStoryOwnerCannotLeaveException.class
                    ));

            assertThat(countOwners(story.id())).isEqualTo(1);
            assertThat(storyRepository.findById(story.id()))
                    .contains(story);
            assertThat(storyParticipantRepository.find(
                    story.id(),
                    firstOwner.id()
            )).isEmpty();
            assertThat(storyParticipantRepository.find(
                    story.id(),
                    secondOwner.id()
            )).isPresent();
        } finally {
            blockingStoryRepository.releaseFirstTransaction();
            executor.shutdownNow();
        }
    }

    private User saveUser(UUID userId) {
        return userRepository.save(new User(
                userId,
                "google-subject-" + userId,
                "Memory Map User",
                null,
                BASE_TIME,
                BASE_TIME
        ));
    }

    private Story saveStory(UUID storyId, UUID ownerId) {
        return storyRepository.save(new Story(
                storyId,
                ownerId,
                "Our Story",
                "The beginning",
                BASE_TIME,
                BASE_TIME
        ));
    }

    private StoryParticipant saveParticipant(
            UUID storyId,
            UUID userId,
            StoryRole role,
            Instant joinedAt
    ) {
        StoryParticipant participant = new StoryParticipant(
                storyId,
                userId,
                role,
                joinedAt
        );
        storyParticipantRepository.save(participant);

        return participant;
    }

    private static LeaveStoryCommand command(UUID userId, UUID storyId) {
        return new LeaveStoryCommand(
                new AuthenticatedUser(userId),
                storyId
        );
    }

    private long countOwners(UUID storyId) {
        return jdbcClient.sql("""
                SELECT COUNT(*)
                FROM story_participants
                WHERE story_id = :storyId
                  AND role = 'OWNER'
                """)
                .param("storyId", storyId)
                .query(Long.class)
                .single();
    }

    private static void assertStoryNotFound(ThrowingAction action) {
        assertThatThrownBy(action::run)
                .isInstanceOf(StoryNotFoundException.class)
                .hasMessage("Story was not found");
    }

    private static StoryNotFoundException catchStoryNotFound(
            ThrowingAction action
    ) {
        try {
            action.run();
        } catch (StoryNotFoundException exception) {
            return exception;
        }

        throw new AssertionError("Expected StoryNotFoundException");
    }

    @TestConfiguration(proxyBeanMethods = false)
    static class LeaveStoryUseCaseTestConfiguration {

        @Bean
        @Primary
        BlockingStoryRepository blockingStoryRepository(
                JdbcStoryRepository delegate
        ) {
            return new BlockingStoryRepository(delegate);
        }

        @Bean
        @Primary
        FailingStoryParticipantRepository
        failingStoryParticipantRepository(
                JdbcStoryParticipantRepository delegate
        ) {
            return new FailingStoryParticipantRepository(delegate);
        }
    }

    static final class BlockingStoryRepository implements StoryRepository {

        private final StoryRepository delegate;
        private final AtomicInteger lockCalls = new AtomicInteger();
        private volatile CountDownLatch firstLockAcquired =
                new CountDownLatch(0);
        private volatile CountDownLatch releaseFirstTransaction =
                new CountDownLatch(0);
        private volatile CountDownLatch secondLockAttemptStarted =
                new CountDownLatch(0);
        private volatile boolean blockFirstLock;

        private BlockingStoryRepository(StoryRepository delegate) {
            this.delegate = delegate;
        }

        @Override
        public Story save(Story story) {
            return delegate.save(story);
        }

        @Override
        public Story update(Story story) {
            return delegate.update(story);
        }

        @Override
        public Optional<Story> findById(UUID id) {
            return delegate.findById(id);
        }

        @Override
        public boolean lockById(UUID id) {
            if (!blockFirstLock) {
                return delegate.lockById(id);
            }

            int call = lockCalls.incrementAndGet();

            if (call == 1) {
                boolean locked = delegate.lockById(id);
                firstLockAcquired.countDown();
                await(releaseFirstTransaction);

                return locked;
            }

            if (call == 2) {
                secondLockAttemptStarted.countDown();
            }

            return delegate.lockById(id);
        }

        @Override
        public List<Story> findByOwnerId(UUID ownerId) {
            return delegate.findByOwnerId(ownerId);
        }

        private void blockFirstLock() {
            lockCalls.set(0);
            firstLockAcquired = new CountDownLatch(1);
            releaseFirstTransaction = new CountDownLatch(1);
            secondLockAttemptStarted = new CountDownLatch(1);
            blockFirstLock = true;
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
            blockFirstLock = false;
            lockCalls.set(0);
            firstLockAcquired = new CountDownLatch(0);
            releaseFirstTransaction = new CountDownLatch(0);
            secondLockAttemptStarted = new CountDownLatch(0);
        }
    }

    static final class FailingStoryParticipantRepository
            implements StoryParticipantRepository {

        private final StoryParticipantRepository delegate;
        private RuntimeException deleteFailure;

        private FailingStoryParticipantRepository(
                StoryParticipantRepository delegate
        ) {
            this.delegate = delegate;
        }

        @Override
        public Optional<StoryParticipant> find(UUID storyId, UUID userId) {
            return delegate.find(storyId, userId);
        }

        @Override
        public List<StoryParticipant> findByStoryId(UUID storyId) {
            return delegate.findByStoryId(storyId);
        }

        @Override
        public List<StoryParticipant> findByUserId(UUID userId) {
            return delegate.findByUserId(userId);
        }

        @Override
        public long countOwners(UUID storyId) {
            return delegate.countOwners(storyId);
        }

        @Override
        public boolean exists(UUID storyId, UUID userId) {
            return delegate.exists(storyId, userId);
        }

        @Override
        public void save(StoryParticipant participant) {
            delegate.save(participant);
        }

        @Override
        public void update(StoryParticipant participant) {
            delegate.update(participant);
        }

        @Override
        public void delete(UUID storyId, UUID userId) {
            delegate.delete(storyId, userId);

            if (deleteFailure != null) {
                assertThat(delegate.find(storyId, userId)).isEmpty();
                throw deleteFailure;
            }
        }

        private void failAfterDelete(RuntimeException failure) {
            deleteFailure = failure;
        }

        private void reset() {
            deleteFailure = null;
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
