package memory_map.backend.invite.application;

import memory_map.backend.IntegrationTest;
import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.invite.domain.Invite;
import memory_map.backend.invite.repository.InviteRepository;
import memory_map.backend.invite.repository.JdbcInviteRepository;
import memory_map.backend.story.application.UserStory;
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

@Import(AcceptInviteUseCaseIntegrationTest.AcceptInviteUseCaseTestConfiguration.class)
class AcceptInviteUseCaseIntegrationTest extends IntegrationTest {

    @Autowired
    private AcceptInviteUseCase acceptInviteUseCase;

    @Autowired
    private InviteRepository inviteRepository;

    @Autowired
    private BlockingInviteRepository blockingInviteRepository;

    @Autowired
    private StoryRepository storyRepository;

    @Autowired
    private HidingStoryRepository hidingStoryRepository;

    @Autowired
    private StoryParticipantRepository storyParticipantRepository;

    @Autowired
    private FailingStoryParticipantRepository
            failingStoryParticipantRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private InviteTokenHasher inviteTokenHasher;

    @Autowired
    private JdbcClient jdbcClient;

    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID OWNER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000002");
    private static final UUID OTHER_USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000003");
    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000011");
    private static final UUID INVITE_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000021");
    private static final String RAW_INVITE_TOKEN =
            "raw_INVITE-token_123";
    private static final String MISSING_RAW_INVITE_TOKEN =
            "missing_INVITE-token_123";
    private static final Instant BASE_TIME =
            Instant.parse("2026-01-01T10:00:00.123456Z");
    private static final Instant CURRENT_TIME =
            Instant.parse("2026-01-10T10:00:00.123456Z");
    private static final Instant EXPIRES_AT =
            Instant.parse("2026-02-09T10:00:00.123456Z");
    private static final String CLEAN_DATABASE_SQL = """
        TRUNCATE TABLE users
        RESTART IDENTITY CASCADE
        """;

    @BeforeEach
    void cleanDatabase() {
        blockingInviteRepository.reset();
        hidingStoryRepository.reset();
        failingStoryParticipantRepository.reset();
        jdbcClient.sql(CLEAN_DATABASE_SQL).update();
    }

    @Test
    void shouldAcceptInviteAndCreateCoOwnerParticipant() {

        User owner = saveUser(OWNER_ID);
        User invitedUser = saveUser(USER_ID);
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        Invite invite = saveInvite(
                INVITE_ID,
                story.id(),
                owner.id(),
                RAW_INVITE_TOKEN,
                EXPIRES_AT,
                null
        );

        UserStory result = acceptInviteUseCase.acceptInvite(command(
                invitedUser.id(),
                RAW_INVITE_TOKEN,
                CURRENT_TIME
        ));

        StoryParticipant participant = storyParticipantRepository.find(
                story.id(),
                invitedUser.id()
        ).orElseThrow();
        Invite consumed = inviteRepository.findById(invite.id())
                .orElseThrow();

        assertThat(result).isEqualTo(new UserStory(
                story,
                StoryRole.CO_OWNER
        ));
        assertThat(participant).isEqualTo(new StoryParticipant(
                story.id(),
                invitedUser.id(),
                StoryRole.CO_OWNER,
                CURRENT_TIME
        ));
        assertThat(consumed.usedAt()).isEqualTo(CURRENT_TIME);
    }

    @Test
    void shouldRejectExpiredInvite() {

        User owner = saveUser(OWNER_ID);
        User invitedUser = saveUser(USER_ID);
        Story story = saveStory(STORY_ID, owner.id());
        saveInvite(
                INVITE_ID,
                story.id(),
                owner.id(),
                RAW_INVITE_TOKEN,
                CURRENT_TIME.minusMillis(1),
                null
        );

        assertInviteUnavailable(() -> acceptInviteUseCase.acceptInvite(
                command(invitedUser.id(), RAW_INVITE_TOKEN, CURRENT_TIME)
        ));

        assertThat(storyParticipantRepository.find(
                story.id(),
                invitedUser.id()
        )).isEmpty();
        assertThat(inviteRepository.findById(INVITE_ID)
                .orElseThrow()
                .usedAt()).isNull();
    }

    @Test
    void shouldRejectAlreadyUsedInvite() {

        User owner = saveUser(OWNER_ID);
        User invitedUser = saveUser(USER_ID);
        Story story = saveStory(STORY_ID, owner.id());
        saveInvite(
                INVITE_ID,
                story.id(),
                owner.id(),
                RAW_INVITE_TOKEN,
                EXPIRES_AT,
                BASE_TIME.plusSeconds(60)
        );

        assertInviteUnavailable(() -> acceptInviteUseCase.acceptInvite(
                command(invitedUser.id(), RAW_INVITE_TOKEN, CURRENT_TIME)
        ));

        assertThat(storyParticipantRepository.find(
                story.id(),
                invitedUser.id()
        )).isEmpty();
        assertThat(inviteRepository.findById(INVITE_ID)
                .orElseThrow()
                .usedAt()).isEqualTo(BASE_TIME.plusSeconds(60));
    }

    @Test
    void shouldRejectNonexistentInvite() {

        User invitedUser = saveUser(USER_ID);

        assertInviteUnavailable(() -> acceptInviteUseCase.acceptInvite(
                command(
                        invitedUser.id(),
                        MISSING_RAW_INVITE_TOKEN,
                        CURRENT_TIME
                )
        ));

        assertThat(participantCount()).isZero();
    }

    @Test
    void shouldRejectInviteWhenStoryLookupReturnsEmpty() {

        User owner = saveUser(OWNER_ID);
        User invitedUser = saveUser(USER_ID);
        Story story = saveStory(STORY_ID, owner.id());
        saveInvite(
                INVITE_ID,
                story.id(),
                owner.id(),
                RAW_INVITE_TOKEN,
                EXPIRES_AT,
                null
        );
        hidingStoryRepository.hide(story.id());

        assertInviteUnavailable(() -> acceptInviteUseCase.acceptInvite(
                command(invitedUser.id(), RAW_INVITE_TOKEN, CURRENT_TIME)
        ));

        assertThat(storyParticipantRepository.find(
                story.id(),
                invitedUser.id()
        )).isEmpty();
        assertThat(inviteRepository.findById(INVITE_ID)
                .orElseThrow()
                .usedAt()).isNull();
    }

    @ParameterizedTest
    @EnumSource(StoryRole.class)
    void shouldRejectAlreadyParticipant(StoryRole role) {

        User owner = saveUser(OWNER_ID);
        User invitedUser = saveUser(USER_ID);
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(story.id(), invitedUser.id(), role);
        saveInvite(
                INVITE_ID,
                story.id(),
                owner.id(),
                RAW_INVITE_TOKEN,
                EXPIRES_AT,
                null
        );

        assertInviteUnavailable(() -> acceptInviteUseCase.acceptInvite(
                command(invitedUser.id(), RAW_INVITE_TOKEN, CURRENT_TIME)
        ));

        assertThat(storyParticipantRepository.find(
                story.id(),
                invitedUser.id()
        )).contains(new StoryParticipant(
                story.id(),
                invitedUser.id(),
                role,
                BASE_TIME
        ));
        assertThat(inviteRepository.findById(INVITE_ID)
                .orElseThrow()
                .usedAt()).isNull();
    }

    @Test
    void shouldRejectDuplicateAcceptanceAfterInviteWasConsumed() {

        User owner = saveUser(OWNER_ID);
        User firstUser = saveUser(USER_ID);
        User secondUser = saveUser(OTHER_USER_ID);
        Story story = saveStory(STORY_ID, owner.id());
        saveInvite(
                INVITE_ID,
                story.id(),
                owner.id(),
                RAW_INVITE_TOKEN,
                EXPIRES_AT,
                null
        );

        acceptInviteUseCase.acceptInvite(command(
                firstUser.id(),
                RAW_INVITE_TOKEN,
                CURRENT_TIME
        ));

        assertInviteUnavailable(() -> acceptInviteUseCase.acceptInvite(
                command(
                        secondUser.id(),
                        RAW_INVITE_TOKEN,
                        CURRENT_TIME.plusSeconds(1)
                )
        ));

        assertThat(storyParticipantRepository.find(
                story.id(),
                firstUser.id()
        )).isPresent();
        assertThat(storyParticipantRepository.find(
                story.id(),
                secondUser.id()
        )).isEmpty();
    }

    @Test
    void shouldRollbackParticipantInsertWhenRepositoryFailsAfterSave() {

        User owner = saveUser(OWNER_ID);
        User invitedUser = saveUser(USER_ID);
        Story story = saveStory(STORY_ID, owner.id());
        saveInvite(
                INVITE_ID,
                story.id(),
                owner.id(),
                RAW_INVITE_TOKEN,
                EXPIRES_AT,
                null
        );
        failingStoryParticipantRepository.failAfterSave(
                new RuntimeException("participant save failed")
        );

        assertThatThrownBy(() -> acceptInviteUseCase.acceptInvite(command(
                invitedUser.id(),
                RAW_INVITE_TOKEN,
                CURRENT_TIME
        )))
                .isInstanceOf(RuntimeException.class)
                .hasMessage("participant save failed");

        assertThat(storyParticipantRepository.find(
                story.id(),
                invitedUser.id()
        )).isEmpty();
        assertThat(inviteRepository.findById(INVITE_ID)
                .orElseThrow()
                .usedAt()).isNull();
    }

    @Test
    void shouldSerializeConcurrentInviteAcceptance() throws Exception {

        User owner = saveUser(OWNER_ID);
        User firstUser = saveUser(USER_ID);
        User secondUser = saveUser(OTHER_USER_ID);
        Story story = saveStory(STORY_ID, owner.id());
        saveInvite(
                INVITE_ID,
                story.id(),
                owner.id(),
                RAW_INVITE_TOKEN,
                EXPIRES_AT,
                null
        );
        ExecutorService executor = Executors.newFixedThreadPool(2);
        blockingInviteRepository.blockFirstFindForUpdate();

        try {
            Future<UserStory> first = executor.submit(() ->
                    acceptInviteUseCase.acceptInvite(command(
                            firstUser.id(),
                            RAW_INVITE_TOKEN,
                            CURRENT_TIME
                    ))
            );

            blockingInviteRepository.awaitFirstLockAcquired();

            Future<UserStory> second = executor.submit(() ->
                    acceptInviteUseCase.acceptInvite(command(
                            secondUser.id(),
                            RAW_INVITE_TOKEN,
                            CURRENT_TIME.plusSeconds(1)
                    ))
            );

            blockingInviteRepository.awaitSecondLockAttemptStarted();
            assertThatThrownBy(() ->
                    second.get(250, TimeUnit.MILLISECONDS))
                    .isInstanceOf(TimeoutException.class);

            blockingInviteRepository.releaseFirstTransaction();

            UserStory firstResult = first.get(10, TimeUnit.SECONDS);

            assertThatThrownBy(() ->
                    second.get(10, TimeUnit.SECONDS))
                    .isInstanceOf(ExecutionException.class)
                    .satisfies(exception -> assertThat(
                            exception.getCause()
                    ).isInstanceOf(
                            InviteAcceptanceUnavailableException.class
                    ));

            assertThat(firstResult.role()).isEqualTo(StoryRole.CO_OWNER);
            assertThat(storyParticipantRepository.find(
                    story.id(),
                    firstUser.id()
            )).isPresent();
            assertThat(storyParticipantRepository.find(
                    story.id(),
                    secondUser.id()
            )).isEmpty();
            assertThat(inviteRepository.findById(INVITE_ID)
                    .orElseThrow()
                    .usedAt()).isEqualTo(CURRENT_TIME);
        } finally {
            blockingInviteRepository.releaseFirstTransaction();
            executor.shutdownNow();
        }
    }

    private User saveUser(UUID userId) {
        return userRepository.save(
                new User(
                        userId,
                        "google-subject-" + userId,
                        "Memory Map User",
                        null,
                        BASE_TIME,
                        BASE_TIME
                )
        );
    }

    private Story saveStory(UUID storyId, UUID ownerId) {
        return storyRepository.save(
                new Story(
                        storyId,
                        ownerId,
                        "Our Story",
                        "The beginning",
                        BASE_TIME,
                        BASE_TIME
                )
        );
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

    private Invite saveInvite(
            UUID inviteId,
            UUID storyId,
            UUID createdBy,
            String rawInviteToken,
            Instant expiresAt,
            Instant usedAt
    ) {
        Invite invite = new Invite(
                inviteId,
                storyId,
                inviteTokenHasher.hash(rawInviteToken),
                createdBy,
                BASE_TIME,
                expiresAt,
                usedAt
        );

        inviteRepository.save(invite);

        return invite;
    }

    private static AcceptInviteCommand command(
            UUID userId,
            String rawInviteToken,
            Instant currentTime
    ) {
        return new AcceptInviteCommand(
                new AuthenticatedUser(userId),
                rawInviteToken,
                currentTime
        );
    }

    private int participantCount() {
        return jdbcClient.sql("""
                SELECT COUNT(*)
                FROM story_participants
                """)
                .query(Integer.class)
                .single();
    }

    private static void assertInviteUnavailable(ThrowingAction action) {
        assertThatThrownBy(action::run)
                .isInstanceOf(InviteAcceptanceUnavailableException.class)
                .hasMessage("Invite could not be accepted");
    }

    @TestConfiguration(proxyBeanMethods = false)
    static class AcceptInviteUseCaseTestConfiguration {

        @Bean
        @Primary
        BlockingInviteRepository blockingInviteRepository(
                JdbcInviteRepository delegate
        ) {
            return new BlockingInviteRepository(delegate);
        }

        @Bean
        @Primary
        HidingStoryRepository hidingStoryRepository(
                JdbcStoryRepository delegate
        ) {
            return new HidingStoryRepository(delegate);
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

    static final class BlockingInviteRepository
            implements InviteRepository {

        private final InviteRepository delegate;
        private final AtomicInteger forUpdateCalls = new AtomicInteger();
        private volatile CountDownLatch firstLockAcquired =
                new CountDownLatch(0);
        private volatile CountDownLatch releaseFirstTransaction =
                new CountDownLatch(0);
        private volatile CountDownLatch secondLockAttemptStarted =
                new CountDownLatch(0);
        private volatile boolean blockFirstFindForUpdate;

        private BlockingInviteRepository(InviteRepository delegate) {
            this.delegate = delegate;
        }

        @Override
        public Optional<Invite> findById(UUID id) {
            return delegate.findById(id);
        }

        @Override
        public Optional<Invite> findByTokenHash(String tokenHash) {
            return delegate.findByTokenHash(tokenHash);
        }

        @Override
        public Optional<Invite> findByTokenHashForUpdate(String tokenHash) {
            if (!blockFirstFindForUpdate) {
                return delegate.findByTokenHashForUpdate(tokenHash);
            }

            int call = forUpdateCalls.incrementAndGet();
            if (call == 1) {
                Optional<Invite> invite =
                        delegate.findByTokenHashForUpdate(tokenHash);
                firstLockAcquired.countDown();
                await(releaseFirstTransaction);

                return invite;
            }

            if (call == 2) {
                secondLockAttemptStarted.countDown();
            }

            return delegate.findByTokenHashForUpdate(tokenHash);
        }

        @Override
        public List<Invite> findByStoryId(UUID storyId) {
            return delegate.findByStoryId(storyId);
        }

        @Override
        public void save(Invite invite) {
            delegate.save(invite);
        }

        @Override
        public boolean markUsedIfUnused(UUID inviteId, Instant usedAt) {
            return delegate.markUsedIfUnused(inviteId, usedAt);
        }

        @Override
        public void delete(UUID id) {
            delegate.delete(id);
        }

        private void blockFirstFindForUpdate() {
            forUpdateCalls.set(0);
            firstLockAcquired = new CountDownLatch(1);
            releaseFirstTransaction = new CountDownLatch(1);
            secondLockAttemptStarted = new CountDownLatch(1);
            blockFirstFindForUpdate = true;
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
            blockFirstFindForUpdate = false;
            forUpdateCalls.set(0);
            firstLockAcquired = new CountDownLatch(0);
            releaseFirstTransaction = new CountDownLatch(0);
            secondLockAttemptStarted = new CountDownLatch(0);
        }
    }

    static final class HidingStoryRepository
            implements StoryRepository {

        private final StoryRepository delegate;
        private UUID hiddenStoryId;

        private HidingStoryRepository(StoryRepository delegate) {
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
            if (id.equals(hiddenStoryId)) {
                return Optional.empty();
            }

            return delegate.findById(id);
        }

        @Override
        public boolean lockById(UUID id) {
            return delegate.lockById(id);
        }

        @Override
        public List<Story> findByOwnerId(UUID ownerId) {
            return delegate.findByOwnerId(ownerId);
        }

        private void hide(UUID storyId) {
            hiddenStoryId = storyId;
        }

        private void reset() {
            hiddenStoryId = null;
        }
    }

    static final class FailingStoryParticipantRepository
            implements StoryParticipantRepository {

        private final StoryParticipantRepository delegate;
        private RuntimeException failure;

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

            if (failure != null) {
                throw failure;
            }
        }

        @Override
        public void update(StoryParticipant participant) {
            delegate.update(participant);
        }

        @Override
        public void delete(UUID storyId, UUID userId) {
            delegate.delete(storyId, userId);
        }

        private void failAfterSave(RuntimeException failure) {
            this.failure = failure;
        }

        private void reset() {
            failure = null;
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
