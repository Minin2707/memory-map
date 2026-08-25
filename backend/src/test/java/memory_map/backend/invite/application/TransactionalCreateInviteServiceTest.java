package memory_map.backend.invite.application;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.invite.domain.Invite;
import memory_map.backend.invite.repository.InviteRepository;
import memory_map.backend.story.application.UserStory;
import memory_map.backend.story.domain.Story;
import memory_map.backend.story.repository.UserStoryRepository;
import memory_map.backend.storyparticipant.domain.StoryRole;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;

import java.net.URI;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class TransactionalCreateInviteServiceTest {

    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID OWNER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000002");
    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000011");
    private static final UUID INVITE_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000021");
    private static final Instant CREATED_AT =
            Instant.parse("2026-01-01T10:00:00.123456Z");
    private static final Instant CURRENT_TIME =
            Instant.parse("2026-01-10T10:00:00.123456Z");
    private static final Duration TTL = Duration.ofDays(30);
    private static final Instant EXPIRES_AT = CURRENT_TIME.plus(TTL);
    private static final String RAW_TOKEN = "raw_INVITE-token_123";
    private static final String TOKEN_HASH = "sha256-token-hash";
    private static final URI INVITE_LINK =
            URI.create("https://app.memorymap.app/invite/" + RAW_TOKEN);

    @Test
    void shouldCreateInviteForOwner() {

        TestContext context = testContext(userStory(StoryRole.OWNER));

        CreatedInvite result = context.service().createInvite(command());

        assertThat(result).isEqualTo(new CreatedInvite(
                INVITE_LINK,
                EXPIRES_AT
        ));
        assertThat(context.userStoryRepository().receivedStoryId())
                .isEqualTo(STORY_ID);
        assertThat(context.userStoryRepository().receivedUserId())
                .isEqualTo(USER_ID);
        assertThat(context.tokenGenerator().generateCallCount())
                .isEqualTo(1);
        assertThat(context.tokenHasher().receivedRawToken())
                .isEqualTo(RAW_TOKEN);
        assertThat(context.linkFactory().receivedRawToken())
                .isEqualTo(RAW_TOKEN);
        assertThat(context.inviteRepository().savedInvite())
                .isEqualTo(expectedInvite());
        assertThat(context.inviteRepository().savedInvite().tokenHash())
                .isEqualTo(TOKEN_HASH)
                .isNotEqualTo(RAW_TOKEN);
        assertThat(context.calls()).containsExactly(
                "find UserStory",
                "generate token",
                "hash token",
                "save Invite",
                "create link"
        );
    }

    @Test
    void shouldCreateInviteForCoOwner() {

        TestContext context = testContext(userStory(StoryRole.CO_OWNER));

        CreatedInvite result = context.service().createInvite(command());

        assertThat(result.inviteLink()).isEqualTo(INVITE_LINK);
        assertThat(context.inviteRepository().savedInvite())
                .isEqualTo(expectedInvite());
    }

    @ParameterizedTest
    @EnumSource(value = StoryRole.class, names = {"EDITOR", "VIEWER"})
    void shouldDenyRolesThatCannotCreateInvite(StoryRole role) {

        TestContext context = testContext(userStory(role));

        assertInviteUnavailable(
                () -> context.service().createInvite(command())
        );

        assertThat(context.tokenGenerator().generateCallCount()).isZero();
        assertThat(context.tokenHasher().hashCallCount()).isZero();
        assertThat(context.inviteRepository().saveCallCount()).isZero();
        assertThat(context.linkFactory().createCallCount()).isZero();
    }

    @Test
    void shouldThrowInviteUnavailableWhenStoryIsMissingOrInaccessible() {

        TestContext context = testContext(Optional.empty());

        assertInviteUnavailable(
                () -> context.service().createInvite(command())
        );

        assertThat(context.tokenGenerator().generateCallCount()).isZero();
        assertThat(context.tokenHasher().hashCallCount()).isZero();
        assertThat(context.inviteRepository().saveCallCount()).isZero();
        assertThat(context.linkFactory().createCallCount()).isZero();
    }

    @Test
    void shouldDenyOwnerWithoutMembershipWhenLookupIsEmpty() {

        TestContext context = testContext(Optional.empty());

        assertInviteUnavailable(
                () -> context.service().createInvite(command())
        );

        assertThat(context.userStoryRepository().receivedStoryId())
                .isEqualTo(STORY_ID);
        assertThat(context.userStoryRepository().receivedUserId())
                .isEqualTo(USER_ID);
        assertThat(context.inviteRepository().saveCallCount()).isZero();
    }

    @Test
    void shouldUseCommandValuesAndConfiguredTtl() {

        TestContext context = testContext(userStory(StoryRole.OWNER));

        context.service().createInvite(command());

        Invite saved = context.inviteRepository().savedInvite();

        assertThat(saved.id()).isEqualTo(INVITE_ID);
        assertThat(saved.storyId()).isEqualTo(STORY_ID);
        assertThat(saved.tokenHash()).isEqualTo(TOKEN_HASH);
        assertThat(saved.createdBy()).isEqualTo(USER_ID);
        assertThat(saved.createdAt()).isEqualTo(CURRENT_TIME);
        assertThat(saved.expiresAt()).isEqualTo(EXPIRES_AT);
        assertThat(saved.usedAt()).isNull();
    }

    @Test
    void shouldNotReadOrReuseExistingInvites() {

        TestContext context = testContext(userStory(StoryRole.OWNER));

        context.service().createInvite(command());

        assertThat(context.inviteRepository().findByStoryIdCallCount())
                .isZero();
        assertThat(context.inviteRepository().saveCallCount()).isEqualTo(1);
    }

    @Test
    void shouldRejectNullUserStoryRepositoryDependency() {

        TestContext context = testContext(userStory(StoryRole.OWNER));

        assertThatThrownBy(() -> new TransactionalCreateInviteService(
                null,
                context.inviteRepository(),
                context.tokenGenerator(),
                context.tokenHasher(),
                context.linkFactory(),
                context.inviteProperties()
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("userStoryRepository must not be null");
    }

    @Test
    void shouldRejectNullInviteRepositoryDependency() {

        TestContext context = testContext(userStory(StoryRole.OWNER));

        assertThatThrownBy(() -> new TransactionalCreateInviteService(
                context.userStoryRepository(),
                null,
                context.tokenGenerator(),
                context.tokenHasher(),
                context.linkFactory(),
                context.inviteProperties()
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("inviteRepository must not be null");
    }

    @Test
    void shouldRejectNullInviteTokenGeneratorDependency() {

        TestContext context = testContext(userStory(StoryRole.OWNER));

        assertThatThrownBy(() -> new TransactionalCreateInviteService(
                context.userStoryRepository(),
                context.inviteRepository(),
                null,
                context.tokenHasher(),
                context.linkFactory(),
                context.inviteProperties()
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("inviteTokenGenerator must not be null");
    }

    @Test
    void shouldRejectNullInviteTokenHasherDependency() {

        TestContext context = testContext(userStory(StoryRole.OWNER));

        assertThatThrownBy(() -> new TransactionalCreateInviteService(
                context.userStoryRepository(),
                context.inviteRepository(),
                context.tokenGenerator(),
                null,
                context.linkFactory(),
                context.inviteProperties()
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("inviteTokenHasher must not be null");
    }

    @Test
    void shouldRejectNullInviteLinkFactoryDependency() {

        TestContext context = testContext(userStory(StoryRole.OWNER));

        assertThatThrownBy(() -> new TransactionalCreateInviteService(
                context.userStoryRepository(),
                context.inviteRepository(),
                context.tokenGenerator(),
                context.tokenHasher(),
                null,
                context.inviteProperties()
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("inviteLinkFactory must not be null");
    }

    @Test
    void shouldRejectNullInvitePropertiesDependency() {

        TestContext context = testContext(userStory(StoryRole.OWNER));

        assertThatThrownBy(() -> new TransactionalCreateInviteService(
                context.userStoryRepository(),
                context.inviteRepository(),
                context.tokenGenerator(),
                context.tokenHasher(),
                context.linkFactory(),
                null
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("inviteProperties must not be null");
    }

    @Test
    void shouldRejectNullCommand() {

        assertThatThrownBy(() -> testContext(
                userStory(StoryRole.OWNER)
        ).service().createInvite(null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("command must not be null");
    }

    @Test
    void shouldPropagateLookupRepositoryFailure() {

        RuntimeException failure =
                new RuntimeException("lookup failed");
        TestContext context = testContext(userStory(StoryRole.OWNER));
        context.userStoryRepository().failOnLookup(failure);

        assertThatThrownBy(() -> context.service().createInvite(command()))
                .isSameAs(failure);

        assertThat(context.tokenGenerator().generateCallCount()).isZero();
        assertThat(context.inviteRepository().saveCallCount()).isZero();
    }

    @Test
    void shouldPropagateTokenGeneratorFailure() {

        RuntimeException failure =
                new RuntimeException("token generation failed");
        TestContext context = testContext(userStory(StoryRole.OWNER));
        context.tokenGenerator().failOnGenerate(failure);

        assertThatThrownBy(() -> context.service().createInvite(command()))
                .isSameAs(failure);

        assertThat(context.tokenHasher().hashCallCount()).isZero();
        assertThat(context.inviteRepository().saveCallCount()).isZero();
        assertThat(context.linkFactory().createCallCount()).isZero();
    }

    @Test
    void shouldPropagateTokenHasherFailure() {

        RuntimeException failure =
                new RuntimeException("token hashing failed");
        TestContext context = testContext(userStory(StoryRole.OWNER));
        context.tokenHasher().failOnHash(failure);

        assertThatThrownBy(() -> context.service().createInvite(command()))
                .isSameAs(failure);

        assertThat(context.inviteRepository().saveCallCount()).isZero();
        assertThat(context.linkFactory().createCallCount()).isZero();
    }

    @Test
    void shouldPropagateInviteSaveFailure() {

        RuntimeException failure =
                new RuntimeException("invite save failed");
        TestContext context = testContext(userStory(StoryRole.OWNER));
        context.inviteRepository().failOnSave(failure);

        assertThatThrownBy(() -> context.service().createInvite(command()))
                .isSameAs(failure);

        assertThat(context.linkFactory().createCallCount()).isZero();
    }

    @Test
    void shouldPropagateLinkFactoryFailureAfterSave() {

        RuntimeException failure =
                new RuntimeException("link creation failed");
        TestContext context = testContext(userStory(StoryRole.OWNER));
        context.linkFactory().failOnCreate(failure);

        assertThatThrownBy(() -> context.service().createInvite(command()))
                .isSameAs(failure);

        assertThat(context.inviteRepository().saveCallCount()).isEqualTo(1);
        assertThat(context.calls()).containsExactly(
                "find UserStory",
                "generate token",
                "hash token",
                "save Invite",
                "create link"
        );
    }

    @Test
    void shouldPropagateExpirationOverflow() {

        TestContext context = testContext(
                userStory(StoryRole.OWNER),
                Duration.ofDays(1)
        );

        CreateInviteCommand command = new CreateInviteCommand(
                new AuthenticatedUser(USER_ID),
                STORY_ID,
                INVITE_ID,
                Instant.MAX
        );

        assertThatThrownBy(() -> context.service().createInvite(command))
                .isInstanceOf(RuntimeException.class)
                .isNotInstanceOf(InviteCreationUnavailableException.class);

        assertThat(context.inviteRepository().saveCallCount()).isZero();
        assertThat(context.linkFactory().createCallCount()).isZero();
    }

    @Test
    void shouldKeepFailureConfidentialAndResultToStringRedacted() {

        TestContext context = testContext(userStory(StoryRole.VIEWER));

        InviteCreationUnavailableException exception =
                catchInviteUnavailable(
                        () -> context.service().createInvite(command())
                );

        assertThat(exception.getMessage())
                .isEqualTo("Invite could not be created")
                .doesNotContain(STORY_ID.toString())
                .doesNotContain(USER_ID.toString())
                .doesNotContain(StoryRole.VIEWER.name())
                .doesNotContain("token")
                .doesNotContain("hash");

        CreatedInvite result = testContext(userStory(StoryRole.OWNER))
                .service()
                .createInvite(command());

        assertThat(result.toString())
                .contains("inviteLink=<redacted>")
                .doesNotContain(RAW_TOKEN)
                .doesNotContain(INVITE_LINK.toString());
    }

    private static TestContext testContext(Optional<UserStory> userStory) {
        return testContext(userStory, TTL);
    }

    private static TestContext testContext(
            Optional<UserStory> userStory,
            Duration ttl
    ) {
        List<String> calls = new ArrayList<>();
        FakeUserStoryRepository userStoryRepository =
                new FakeUserStoryRepository(calls, userStory);
        FakeInviteRepository inviteRepository =
                new FakeInviteRepository(calls);
        FakeInviteTokenGenerator tokenGenerator =
                new FakeInviteTokenGenerator(calls);
        FakeInviteTokenHasher tokenHasher =
                new FakeInviteTokenHasher(calls);
        FakeInviteLinkFactory linkFactory =
                new FakeInviteLinkFactory(calls);
        InviteProperties inviteProperties = new InviteProperties(
                ttl,
                URI.create("https://app.memorymap.app")
        );

        return new TestContext(
                new TransactionalCreateInviteService(
                        userStoryRepository,
                        inviteRepository,
                        tokenGenerator,
                        tokenHasher,
                        linkFactory,
                        inviteProperties
                ),
                userStoryRepository,
                inviteRepository,
                tokenGenerator,
                tokenHasher,
                linkFactory,
                inviteProperties,
                calls
        );
    }

    private static Optional<UserStory> userStory(StoryRole role) {
        return Optional.of(new UserStory(
                new Story(
                        STORY_ID,
                        OWNER_ID,
                        "Our Story",
                        "The beginning",
                        null,
                        CREATED_AT,
                        CREATED_AT
                ),
                role
        ));
    }

    private static CreateInviteCommand command() {
        return new CreateInviteCommand(
                new AuthenticatedUser(USER_ID),
                STORY_ID,
                INVITE_ID,
                CURRENT_TIME
        );
    }

    private static Invite expectedInvite() {
        return new Invite(
                INVITE_ID,
                STORY_ID,
                TOKEN_HASH,
                USER_ID,
                CURRENT_TIME,
                EXPIRES_AT,
                null
        );
    }

    private static void assertInviteUnavailable(ThrowingAction action) {
        assertThatThrownBy(action::run)
                .isInstanceOf(InviteCreationUnavailableException.class)
                .hasMessage("Invite could not be created");
    }

    private static InviteCreationUnavailableException catchInviteUnavailable(
            ThrowingAction action
    ) {
        try {
            action.run();
        } catch (InviteCreationUnavailableException exception) {
            return exception;
        }

        throw new AssertionError(
                "Expected InviteCreationUnavailableException"
        );
    }

    private record TestContext(

            TransactionalCreateInviteService service,

            FakeUserStoryRepository userStoryRepository,

            FakeInviteRepository inviteRepository,

            FakeInviteTokenGenerator tokenGenerator,

            FakeInviteTokenHasher tokenHasher,

            FakeInviteLinkFactory linkFactory,

            InviteProperties inviteProperties,

            List<String> calls

    ) {
    }

    private static final class FakeUserStoryRepository
            implements UserStoryRepository {

        private final List<String> calls;
        private final Optional<UserStory> userStory;
        private UUID receivedStoryId;
        private UUID receivedUserId;
        private RuntimeException failure;

        private FakeUserStoryRepository(
                List<String> calls,
                Optional<UserStory> userStory
        ) {
            this.calls = calls;
            this.userStory = userStory;
        }

        @Override
        public List<UserStory> findByUserId(UUID userId) {
            throw new UnsupportedOperationException();
        }

        @Override
        public Optional<UserStory> findByStoryIdAndUserId(
                UUID storyId,
                UUID userId
        ) {
            calls.add("find UserStory");
            receivedStoryId = storyId;
            receivedUserId = userId;

            if (failure != null) {
                throw failure;
            }

            return userStory;
        }

        private UUID receivedStoryId() {
            return receivedStoryId;
        }

        private UUID receivedUserId() {
            return receivedUserId;
        }

        private void failOnLookup(RuntimeException failure) {
            this.failure = failure;
        }
    }

    private static final class FakeInviteRepository
            implements InviteRepository {

        private final List<String> calls;
        private Invite savedInvite;
        private int saveCallCount;
        private int findByStoryIdCallCount;
        private RuntimeException failure;

        private FakeInviteRepository(List<String> calls) {
            this.calls = calls;
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
            throw new UnsupportedOperationException();
        }

        @Override
        public List<Invite> findByStoryId(UUID storyId) {
            findByStoryIdCallCount++;
            return List.of();
        }

        @Override
        public void save(Invite invite) {
            calls.add("save Invite");
            saveCallCount++;

            if (failure != null) {
                throw failure;
            }

            savedInvite = invite;
        }

        @Override
        public boolean markUsedIfUnused(UUID inviteId, Instant usedAt) {
            throw new UnsupportedOperationException();
        }

        @Override
        public void delete(UUID id) {
            throw new UnsupportedOperationException();
        }

        private Invite savedInvite() {
            return savedInvite;
        }

        private int saveCallCount() {
            return saveCallCount;
        }

        private int findByStoryIdCallCount() {
            return findByStoryIdCallCount;
        }

        private void failOnSave(RuntimeException failure) {
            this.failure = failure;
        }
    }

    private static final class FakeInviteTokenGenerator
            implements InviteTokenGenerator {

        private final List<String> calls;
        private int generateCallCount;
        private RuntimeException failure;

        private FakeInviteTokenGenerator(List<String> calls) {
            this.calls = calls;
        }

        @Override
        public String generate() {
            calls.add("generate token");
            generateCallCount++;

            if (failure != null) {
                throw failure;
            }

            return RAW_TOKEN;
        }

        private int generateCallCount() {
            return generateCallCount;
        }

        private void failOnGenerate(RuntimeException failure) {
            this.failure = failure;
        }
    }

    private static final class FakeInviteTokenHasher
            implements InviteTokenHasher {

        private final List<String> calls;
        private int hashCallCount;
        private String receivedRawToken;
        private RuntimeException failure;

        private FakeInviteTokenHasher(List<String> calls) {
            this.calls = calls;
        }

        @Override
        public String hash(String rawToken) {
            calls.add("hash token");
            hashCallCount++;
            receivedRawToken = rawToken;

            if (failure != null) {
                throw failure;
            }

            return TOKEN_HASH;
        }

        private int hashCallCount() {
            return hashCallCount;
        }

        private String receivedRawToken() {
            return receivedRawToken;
        }

        private void failOnHash(RuntimeException failure) {
            this.failure = failure;
        }
    }

    private static final class FakeInviteLinkFactory
            implements InviteLinkFactory {

        private final List<String> calls;
        private int createCallCount;
        private String receivedRawToken;
        private RuntimeException failure;

        private FakeInviteLinkFactory(List<String> calls) {
            this.calls = calls;
        }

        @Override
        public URI create(String rawToken) {
            calls.add("create link");
            createCallCount++;
            receivedRawToken = rawToken;

            if (failure != null) {
                throw failure;
            }

            return INVITE_LINK;
        }

        private int createCallCount() {
            return createCallCount;
        }

        private String receivedRawToken() {
            return receivedRawToken;
        }

        private void failOnCreate(RuntimeException failure) {
            this.failure = failure;
        }
    }

    @FunctionalInterface
    private interface ThrowingAction {

        void run();
    }
}
