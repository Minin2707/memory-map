package memory_map.backend.invite.application;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.invite.domain.Invite;
import memory_map.backend.invite.repository.InviteRepository;
import memory_map.backend.story.application.UserStory;
import memory_map.backend.story.domain.Story;
import memory_map.backend.story.repository.StoryRepository;
import memory_map.backend.storyparticipant.domain.StoryParticipant;
import memory_map.backend.storyparticipant.domain.StoryRole;
import memory_map.backend.storyparticipant.repository.StoryParticipantRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class TransactionalAcceptInviteServiceTest {

    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID OWNER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000002");
    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000011");
    private static final UUID INVITE_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000021");
    private static final String RAW_INVITE_TOKEN =
            "raw_INVITE-token_123";
    private static final String TOKEN_HASH = "sha256-token-hash";
    private static final Instant CREATED_AT =
            Instant.parse("2026-01-01T10:00:00.123456Z");
    private static final Instant CURRENT_TIME =
            Instant.parse("2026-01-10T10:00:00.123456Z");
    private static final Instant EXPIRES_AT =
            Instant.parse("2026-02-09T10:00:00.123456Z");

    @Test
    void shouldAcceptInvite() {

        TestContext context = testContext();

        UserStory result = context.service().acceptInvite(command());

        assertThat(result).isEqualTo(new UserStory(
                story(),
                StoryRole.CO_OWNER
        ));
        assertThat(context.tokenHasher().receivedRawToken())
                .isEqualTo(RAW_INVITE_TOKEN);
        assertThat(context.inviteRepository().receivedTokenHash())
                .isEqualTo(TOKEN_HASH);
        assertThat(context.storyRepository().receivedStoryId())
                .isEqualTo(STORY_ID);
        assertThat(context.storyParticipantRepository()
                .receivedExistsStoryId()).isEqualTo(STORY_ID);
        assertThat(context.storyParticipantRepository()
                .receivedExistsUserId()).isEqualTo(USER_ID);
        assertThat(context.storyParticipantRepository().savedParticipant())
                .isEqualTo(new StoryParticipant(
                        STORY_ID,
                        USER_ID,
                        StoryRole.CO_OWNER,
                        CURRENT_TIME
                ));
        assertThat(context.inviteRepository().receivedMarkUsedInviteId())
                .isEqualTo(INVITE_ID);
        assertThat(context.inviteRepository().receivedUsedAt())
                .isEqualTo(CURRENT_TIME);
        assertThat(context.calls()).containsExactly(
                "hash token",
                "find Invite for update",
                "find Story",
                "exists StoryParticipant",
                "save StoryParticipant",
                "mark Invite used"
        );
    }

    @Test
    void shouldReturnUserStoryWithCoOwnerRole() {

        UserStory result = testContext()
                .service()
                .acceptInvite(command());

        assertThat(result.story()).isEqualTo(story());
        assertThat(result.role()).isEqualTo(StoryRole.CO_OWNER);
    }

    @Test
    void shouldThrowInviteUnavailableWhenInviteIsMissing() {

        TestContext context = testContext();
        context.inviteRepository().invite(Optional.empty());

        assertInviteUnavailable(() -> context.service()
                .acceptInvite(command()));

        assertThat(context.storyRepository().findByIdCallCount()).isZero();
        assertThat(context.storyParticipantRepository().saveCallCount())
                .isZero();
        assertThat(context.inviteRepository().markUsedCallCount()).isZero();
    }

    @Test
    void shouldThrowInviteUnavailableWhenInviteIsExpired() {

        TestContext context = testContext(invite(
                EXPIRES_AT,
                null
        ));

        AcceptInviteCommand command = new AcceptInviteCommand(
                new AuthenticatedUser(USER_ID),
                RAW_INVITE_TOKEN,
                EXPIRES_AT.plusNanos(1)
        );

        assertInviteUnavailable(() -> context.service()
                .acceptInvite(command));

        assertThat(context.storyRepository().findByIdCallCount()).isZero();
        assertThat(context.storyParticipantRepository().saveCallCount())
                .isZero();
        assertThat(context.inviteRepository().markUsedCallCount()).isZero();
    }

    @Test
    void shouldAllowInviteAtExactExpirationInstant() {

        TestContext context = testContext(invite(
                EXPIRES_AT,
                null
        ));

        AcceptInviteCommand command = new AcceptInviteCommand(
                new AuthenticatedUser(USER_ID),
                RAW_INVITE_TOKEN,
                EXPIRES_AT
        );

        UserStory result = context.service().acceptInvite(command);

        assertThat(result.role()).isEqualTo(StoryRole.CO_OWNER);
        assertThat(context.inviteRepository().markUsedCallCount())
                .isEqualTo(1);
    }

    @Test
    void shouldThrowInviteUnavailableWhenInviteIsAlreadyUsed() {

        TestContext context = testContext(invite(
                EXPIRES_AT,
                CREATED_AT.plusSeconds(60)
        ));

        assertInviteUnavailable(() -> context.service()
                .acceptInvite(command()));

        assertThat(context.storyRepository().findByIdCallCount()).isZero();
        assertThat(context.storyParticipantRepository().saveCallCount())
                .isZero();
        assertThat(context.inviteRepository().markUsedCallCount()).isZero();
    }

    @Test
    void shouldThrowInviteUnavailableWhenStoryIsMissing() {

        TestContext context = testContext();
        context.storyRepository().story(Optional.empty());

        assertInviteUnavailable(() -> context.service()
                .acceptInvite(command()));

        assertThat(context.storyParticipantRepository().saveCallCount())
                .isZero();
        assertThat(context.inviteRepository().markUsedCallCount()).isZero();
    }

    @ParameterizedTest
    @EnumSource(StoryRole.class)
    void shouldThrowInviteUnavailableWhenUserIsAlreadyParticipant(
            StoryRole role
    ) {

        TestContext context = testContext();
        context.storyParticipantRepository()
                .existingParticipant(new StoryParticipant(
                        STORY_ID,
                        USER_ID,
                        role,
                        CREATED_AT
                ));

        assertInviteUnavailable(() -> context.service()
                .acceptInvite(command()));

        assertThat(context.storyParticipantRepository().saveCallCount())
                .isZero();
        assertThat(context.inviteRepository().markUsedCallCount()).isZero();
    }

    @Test
    void shouldThrowInviteUnavailableWhenMarkUsedReturnsFalse() {

        TestContext context = testContext();
        context.inviteRepository().markUsedResult(false);

        assertInviteUnavailable(() -> context.service()
                .acceptInvite(command()));

        assertThat(context.storyParticipantRepository().saveCallCount())
                .isEqualTo(1);
        assertThat(context.inviteRepository().markUsedCallCount())
                .isEqualTo(1);
    }

    @Test
    void shouldRejectNullInviteRepositoryDependency() {

        TestContext context = testContext();

        assertThatThrownBy(() -> new TransactionalAcceptInviteService(
                null,
                context.tokenHasher(),
                context.storyRepository(),
                context.storyParticipantRepository()
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("inviteRepository must not be null");
    }

    @Test
    void shouldRejectNullInviteTokenHasherDependency() {

        TestContext context = testContext();

        assertThatThrownBy(() -> new TransactionalAcceptInviteService(
                context.inviteRepository(),
                null,
                context.storyRepository(),
                context.storyParticipantRepository()
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("inviteTokenHasher must not be null");
    }

    @Test
    void shouldRejectNullStoryRepositoryDependency() {

        TestContext context = testContext();

        assertThatThrownBy(() -> new TransactionalAcceptInviteService(
                context.inviteRepository(),
                context.tokenHasher(),
                null,
                context.storyParticipantRepository()
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("storyRepository must not be null");
    }

    @Test
    void shouldRejectNullStoryParticipantRepositoryDependency() {

        TestContext context = testContext();

        assertThatThrownBy(() -> new TransactionalAcceptInviteService(
                context.inviteRepository(),
                context.tokenHasher(),
                context.storyRepository(),
                null
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("storyParticipantRepository must not be null");
    }

    @Test
    void shouldRejectNullCommand() {

        assertThatThrownBy(() -> testContext()
                .service()
                .acceptInvite(null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("command must not be null");
    }

    @Test
    void shouldPropagateTokenHasherFailure() {

        RuntimeException failure =
                new RuntimeException("hash failed");
        TestContext context = testContext();
        context.tokenHasher().failOnHash(failure);

        assertThatThrownBy(() -> context.service()
                .acceptInvite(command()))
                .isSameAs(failure);

        assertThat(context.inviteRepository().findForUpdateCallCount())
                .isZero();
    }

    @Test
    void shouldPropagateInviteLookupFailure() {

        RuntimeException failure =
                new RuntimeException("invite lookup failed");
        TestContext context = testContext();
        context.inviteRepository().failOnFindForUpdate(failure);

        assertThatThrownBy(() -> context.service()
                .acceptInvite(command()))
                .isSameAs(failure);
    }

    @Test
    void shouldPropagateStoryLookupFailure() {

        RuntimeException failure =
                new RuntimeException("story lookup failed");
        TestContext context = testContext();
        context.storyRepository().failOnFindById(failure);

        assertThatThrownBy(() -> context.service()
                .acceptInvite(command()))
                .isSameAs(failure);

        assertThat(context.storyParticipantRepository().saveCallCount())
                .isZero();
    }

    @Test
    void shouldPropagateParticipantExistsFailure() {

        RuntimeException failure =
                new RuntimeException("participant exists failed");
        TestContext context = testContext();
        context.storyParticipantRepository().failOnExists(failure);

        assertThatThrownBy(() -> context.service()
                .acceptInvite(command()))
                .isSameAs(failure);

        assertThat(context.storyParticipantRepository().saveCallCount())
                .isZero();
    }

    @Test
    void shouldPropagateParticipantSaveFailure() {

        RuntimeException failure =
                new RuntimeException("participant save failed");
        TestContext context = testContext();
        context.storyParticipantRepository().failOnSave(failure);

        assertThatThrownBy(() -> context.service()
                .acceptInvite(command()))
                .isSameAs(failure);

        assertThat(context.inviteRepository().markUsedCallCount()).isZero();
    }

    @Test
    void shouldPropagateMarkUsedFailure() {

        RuntimeException failure =
                new RuntimeException("mark used failed");
        TestContext context = testContext();
        context.inviteRepository().failOnMarkUsed(failure);

        assertThatThrownBy(() -> context.service()
                .acceptInvite(command()))
                .isSameAs(failure);
    }

    private static TestContext testContext() {
        return testContext(invite());
    }

    private static TestContext testContext(Invite invite) {
        List<String> calls = new ArrayList<>();
        FakeInviteRepository inviteRepository =
                new FakeInviteRepository(calls, Optional.of(invite));
        FakeInviteTokenHasher tokenHasher =
                new FakeInviteTokenHasher(calls);
        FakeStoryRepository storyRepository =
                new FakeStoryRepository(calls);
        FakeStoryParticipantRepository storyParticipantRepository =
                new FakeStoryParticipantRepository(calls);

        return new TestContext(
                new TransactionalAcceptInviteService(
                        inviteRepository,
                        tokenHasher,
                        storyRepository,
                        storyParticipantRepository
                ),
                inviteRepository,
                tokenHasher,
                storyRepository,
                storyParticipantRepository,
                calls
        );
    }

    private static AcceptInviteCommand command() {
        return new AcceptInviteCommand(
                new AuthenticatedUser(USER_ID),
                RAW_INVITE_TOKEN,
                CURRENT_TIME
        );
    }

    private static Invite invite() {
        return invite(EXPIRES_AT, null);
    }

    private static Invite invite(
            Instant expiresAt,
            Instant usedAt
    ) {
        return new Invite(
                INVITE_ID,
                STORY_ID,
                TOKEN_HASH,
                OWNER_ID,
                CREATED_AT,
                expiresAt,
                usedAt
        );
    }

    private static Story story() {
        return new Story(
                STORY_ID,
                OWNER_ID,
                "Our Story",
                "The beginning",
                CREATED_AT,
                CREATED_AT
        );
    }

    private static void assertInviteUnavailable(ThrowingAction action) {
        assertThatThrownBy(action::run)
                .isInstanceOf(InviteAcceptanceUnavailableException.class)
                .hasMessage("Invite could not be accepted");
    }

    private record TestContext(

            TransactionalAcceptInviteService service,

            FakeInviteRepository inviteRepository,

            FakeInviteTokenHasher tokenHasher,

            FakeStoryRepository storyRepository,

            FakeStoryParticipantRepository storyParticipantRepository,

            List<String> calls

    ) {
    }

    private static final class FakeInviteRepository
            implements InviteRepository {

        private final List<String> calls;
        private Optional<Invite> invite;
        private String receivedTokenHash;
        private UUID receivedMarkUsedInviteId;
        private Instant receivedUsedAt;
        private boolean markUsedResult = true;
        private int findForUpdateCallCount;
        private int markUsedCallCount;
        private RuntimeException findForUpdateFailure;
        private RuntimeException markUsedFailure;

        private FakeInviteRepository(
                List<String> calls,
                Optional<Invite> invite
        ) {
            this.calls = calls;
            this.invite = invite;
        }

        @Override
        public Optional<Invite> findById(UUID id) {
            throw new UnsupportedOperationException();
        }

        @Override
        public Optional<Invite> findByTokenHash(String tokenHash) {
            throw new UnsupportedOperationException();
        }

        @Override
        public Optional<Invite> findByTokenHashForUpdate(String tokenHash) {
            calls.add("find Invite for update");
            findForUpdateCallCount++;
            receivedTokenHash = tokenHash;

            if (findForUpdateFailure != null) {
                throw findForUpdateFailure;
            }

            return invite;
        }

        @Override
        public List<Invite> findByStoryId(UUID storyId) {
            throw new UnsupportedOperationException();
        }

        @Override
        public void save(Invite invite) {
            throw new UnsupportedOperationException();
        }

        @Override
        public boolean markUsedIfUnused(UUID inviteId, Instant usedAt) {
            calls.add("mark Invite used");
            markUsedCallCount++;
            receivedMarkUsedInviteId = inviteId;
            receivedUsedAt = usedAt;

            if (markUsedFailure != null) {
                throw markUsedFailure;
            }

            return markUsedResult;
        }

        @Override
        public void delete(UUID id) {
            throw new UnsupportedOperationException();
        }

        private void invite(Optional<Invite> invite) {
            this.invite = invite;
        }

        private String receivedTokenHash() {
            return receivedTokenHash;
        }

        private UUID receivedMarkUsedInviteId() {
            return receivedMarkUsedInviteId;
        }

        private Instant receivedUsedAt() {
            return receivedUsedAt;
        }

        private int findForUpdateCallCount() {
            return findForUpdateCallCount;
        }

        private int markUsedCallCount() {
            return markUsedCallCount;
        }

        private void markUsedResult(boolean markUsedResult) {
            this.markUsedResult = markUsedResult;
        }

        private void failOnFindForUpdate(RuntimeException failure) {
            findForUpdateFailure = failure;
        }

        private void failOnMarkUsed(RuntimeException failure) {
            markUsedFailure = failure;
        }
    }

    private static final class FakeInviteTokenHasher
            implements InviteTokenHasher {

        private final List<String> calls;
        private String receivedRawToken;
        private RuntimeException failure;

        private FakeInviteTokenHasher(List<String> calls) {
            this.calls = calls;
        }

        @Override
        public String hash(String rawToken) {
            calls.add("hash token");
            receivedRawToken = rawToken;

            if (failure != null) {
                throw failure;
            }

            return TOKEN_HASH;
        }

        private String receivedRawToken() {
            return receivedRawToken;
        }

        private void failOnHash(RuntimeException failure) {
            this.failure = failure;
        }
    }

    private static final class FakeStoryRepository
            implements StoryRepository {

        private final List<String> calls;
        private Optional<Story> story = Optional.of(defaultStory());
        private UUID receivedStoryId;
        private int findByIdCallCount;
        private RuntimeException failure;

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
            calls.add("find Story");
            findByIdCallCount++;
            receivedStoryId = id;

            if (failure != null) {
                throw failure;
            }

            return story;
        }

        @Override
        public List<Story> findByOwnerId(UUID ownerId) {
            throw new UnsupportedOperationException();
        }

        private void story(Optional<Story> story) {
            this.story = story;
        }

        private UUID receivedStoryId() {
            return receivedStoryId;
        }

        private int findByIdCallCount() {
            return findByIdCallCount;
        }

        private void failOnFindById(RuntimeException failure) {
            this.failure = failure;
        }

        private static Story defaultStory() {
            return TransactionalAcceptInviteServiceTest.story();
        }
    }

    private static final class FakeStoryParticipantRepository
            implements StoryParticipantRepository {

        private final List<String> calls;
        private StoryParticipant existingParticipant;
        private StoryParticipant savedParticipant;
        private UUID receivedExistsStoryId;
        private UUID receivedExistsUserId;
        private int saveCallCount;
        private RuntimeException existsFailure;
        private RuntimeException saveFailure;

        private FakeStoryParticipantRepository(List<String> calls) {
            this.calls = calls;
        }

        @Override
        public Optional<StoryParticipant> find(UUID storyId, UUID userId) {
            return Optional.ofNullable(existingParticipant);
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
        public boolean exists(UUID storyId, UUID userId) {
            calls.add("exists StoryParticipant");
            receivedExistsStoryId = storyId;
            receivedExistsUserId = userId;

            if (existsFailure != null) {
                throw existsFailure;
            }

            return existingParticipant != null;
        }

        @Override
        public void save(StoryParticipant participant) {
            calls.add("save StoryParticipant");
            saveCallCount++;

            if (saveFailure != null) {
                throw saveFailure;
            }

            savedParticipant = participant;
        }

        @Override
        public void update(StoryParticipant participant) {
            throw new UnsupportedOperationException();
        }

        @Override
        public void delete(UUID storyId, UUID userId) {
            throw new UnsupportedOperationException();
        }

        private void existingParticipant(
                StoryParticipant existingParticipant
        ) {
            this.existingParticipant = existingParticipant;
        }

        private StoryParticipant savedParticipant() {
            return savedParticipant;
        }

        private UUID receivedExistsStoryId() {
            return receivedExistsStoryId;
        }

        private UUID receivedExistsUserId() {
            return receivedExistsUserId;
        }

        private int saveCallCount() {
            return saveCallCount;
        }

        private void failOnExists(RuntimeException failure) {
            existsFailure = failure;
        }

        private void failOnSave(RuntimeException failure) {
            saveFailure = failure;
        }
    }

    @FunctionalInterface
    private interface ThrowingAction {

        void run();
    }
}
