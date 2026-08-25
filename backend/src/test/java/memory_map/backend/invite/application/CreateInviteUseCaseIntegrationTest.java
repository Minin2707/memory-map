package memory_map.backend.invite.application;

import memory_map.backend.IntegrationTest;
import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.invite.domain.Invite;
import memory_map.backend.invite.repository.InviteRepository;
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
import org.springframework.test.context.TestPropertySource;

import java.net.URI;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayDeque;
import java.util.List;
import java.util.Queue;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

@Import(CreateInviteUseCaseIntegrationTest.CreateInviteUseCaseTestConfiguration.class)
@TestPropertySource(properties = {
        "app.invite.ttl=PT48H",
        "app.invite.base-url=https://test.memorymap.app"
})
class CreateInviteUseCaseIntegrationTest extends IntegrationTest {

    @Autowired
    private CreateInviteUseCase createInviteUseCase;

    @Autowired
    private InviteRepository inviteRepository;

    @Autowired
    private InviteTokenHasher inviteTokenHasher;

    @Autowired
    private DeterministicInviteTokenGenerator inviteTokenGenerator;

    @Autowired
    private FailingInviteLinkFactory failingInviteLinkFactory;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private StoryRepository storyRepository;

    @Autowired
    private StoryParticipantRepository storyParticipantRepository;

    @Autowired
    private InviteProperties inviteProperties;

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
    private static final UUID OTHER_STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000012");
    private static final UUID INVITE_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000021");
    private static final UUID SECOND_INVITE_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000022");
    private static final Instant BASE_TIME =
            Instant.parse("2026-01-01T10:00:00.123456Z");
    private static final Instant CURRENT_TIME =
            Instant.parse("2026-01-10T10:00:00.123456Z");
    private static final String FIRST_RAW_TOKEN = "first_INVITE-token_123";
    private static final String SECOND_RAW_TOKEN = "second_INVITE-token_123";
    private static final String COLLISION_RAW_TOKEN = "same_INVITE-token_123";
    private static final String CLEAN_DATABASE_SQL = """
        TRUNCATE TABLE users
        RESTART IDENTITY CASCADE
        """;

    @BeforeEach
    void cleanDatabase() {
        inviteTokenGenerator.reset();
        failingInviteLinkFactory.reset();
        jdbcClient.sql(CLEAN_DATABASE_SQL).update();
    }

    @Test
    void shouldCreateInviteForOwner() {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        Story story = saveStory(
                STORY_ID,
                owner.id(),
                "Our Story",
                "The beginning"
        );
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);

        CreatedInvite result = createInviteUseCase.createInvite(command(
                owner.id(),
                story.id(),
                INVITE_ID
        ));

        Invite persisted = inviteRepository.findById(INVITE_ID)
                .orElseThrow();
        String rawToken = rawTokenFrom(result.inviteLink());
        String expectedHash = inviteTokenHasher.hash(rawToken);

        assertThat(result.inviteLink())
                .isEqualTo(URI.create(
                        "https://test.memorymap.app/invite/"
                                + FIRST_RAW_TOKEN
                ));
        assertThat(result.expiresAt())
                .isEqualTo(CURRENT_TIME.plus(inviteProperties.ttl()));
        assertThat(persisted.id()).isEqualTo(INVITE_ID);
        assertThat(persisted.storyId()).isEqualTo(story.id());
        assertThat(persisted.tokenHash()).isEqualTo(expectedHash);
        assertThat(persisted.tokenHash()).isNotEqualTo(rawToken);
        assertThat(persisted.createdBy()).isEqualTo(owner.id());
        assertThat(persisted.createdAt()).isEqualTo(CURRENT_TIME);
        assertThat(persisted.expiresAt())
                .isEqualTo(CURRENT_TIME.plus(Duration.ofHours(48)));
        assertThat(persisted.usedAt()).isNull();
        assertThat(inviteCountByTokenHash(rawToken)).isZero();
    }

    @Test
    void shouldCreateInviteForCoOwner() {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        User coOwner = saveUser(USER_ID, "co-owner-google-subject");
        Story story = saveStory(
                STORY_ID,
                owner.id(),
                "Our Story",
                "The beginning"
        );
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        saveParticipant(story.id(), coOwner.id(), StoryRole.CO_OWNER);

        CreatedInvite result = createInviteUseCase.createInvite(command(
                coOwner.id(),
                story.id(),
                INVITE_ID
        ));

        Invite persisted = inviteRepository.findById(INVITE_ID)
                .orElseThrow();

        assertThat(result.inviteLink().isAbsolute()).isTrue();
        assertThat(persisted.createdBy()).isEqualTo(coOwner.id());
        assertThat(persisted.storyId()).isEqualTo(story.id());
    }

    @Test
    void shouldDenyEditorAndCreateNoInvite() {

        assertDeniedRoleCreatesNoInvite(StoryRole.EDITOR);
    }

    @Test
    void shouldDenyViewerAndCreateNoInvite() {

        assertDeniedRoleCreatesNoInvite(StoryRole.VIEWER);
    }

    @Test
    void shouldThrowInviteUnavailableWhenStoryDoesNotExist() {

        User user = saveUser(USER_ID, "current-google-subject");

        assertInviteUnavailable(() -> createInviteUseCase.createInvite(
                command(user.id(), STORY_ID, INVITE_ID)
        ));

        assertThat(inviteCount()).isZero();
    }

    @Test
    void shouldThrowSameInviteUnavailableWhenStoryIsInaccessible() {

        User user = saveUser(USER_ID, "current-google-subject");
        User owner = saveUser(OWNER_ID, "owner-google-subject");
        Story story = saveStory(
                STORY_ID,
                owner.id(),
                "Private Story",
                "The beginning"
        );
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);

        InviteCreationUnavailableException inaccessible =
                catchInviteUnavailable(() -> createInviteUseCase.createInvite(
                        command(user.id(), story.id(), INVITE_ID)
                ));
        InviteCreationUnavailableException missing =
                catchInviteUnavailable(() -> createInviteUseCase.createInvite(
                        command(user.id(), OTHER_STORY_ID, SECOND_INVITE_ID)
                ));

        assertThat(inaccessible).hasMessage("Invite could not be created");
        assertThat(missing).hasMessage("Invite could not be created");
        assertThat(inaccessible.getClass()).isEqualTo(missing.getClass());
        assertThat(inaccessible.getMessage())
                .isEqualTo(missing.getMessage());
        assertThat(inviteCount()).isZero();
    }

    @Test
    void shouldDenyOwnerWithoutMembership() {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        Story story = saveStory(
                STORY_ID,
                owner.id(),
                "Owner Without Membership Story",
                "The beginning"
        );

        assertInviteUnavailable(() -> createInviteUseCase.createInvite(
                command(owner.id(), story.id(), INVITE_ID)
        ));

        assertThat(inviteCount()).isZero();
    }

    @Test
    void shouldDenyWrongMembershipUser() {

        User user = saveUser(USER_ID, "current-google-subject");
        User otherUser = saveUser(OTHER_USER_ID, "other-google-subject");
        Story story = saveStory(
                STORY_ID,
                otherUser.id(),
                "Wrong User Story",
                "The beginning"
        );
        saveParticipant(story.id(), otherUser.id(), StoryRole.OWNER);

        assertInviteUnavailable(() -> createInviteUseCase.createInvite(
                command(user.id(), story.id(), INVITE_ID)
        ));

        assertThat(inviteCount()).isZero();
    }

    @Test
    void shouldCreateMultipleActiveInvitesForSameStory() {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        Story story = saveStory(
                STORY_ID,
                owner.id(),
                "Our Story",
                "The beginning"
        );
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        inviteTokenGenerator.useTokens(
                FIRST_RAW_TOKEN,
                SECOND_RAW_TOKEN
        );

        createInviteUseCase.createInvite(command(
                owner.id(),
                story.id(),
                INVITE_ID
        ));
        createInviteUseCase.createInvite(command(
                owner.id(),
                story.id(),
                SECOND_INVITE_ID
        ));

        List<Invite> invites = inviteRepository.findByStoryId(story.id());

        assertThat(invites).hasSize(2);
        assertThat(invites)
                .extracting(Invite::id)
                .containsExactly(INVITE_ID, SECOND_INVITE_ID);
        assertThat(invites)
                .extracting(Invite::tokenHash)
                .doesNotHaveDuplicates();
        assertThat(invites)
                .allSatisfy(invite -> assertThat(invite.usedAt()).isNull());
    }

    @Test
    void shouldPropagateUniqueTokenHashCollision() {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        Story story = saveStory(
                STORY_ID,
                owner.id(),
                "Our Story",
                "The beginning"
        );
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        inviteTokenGenerator.useTokens(
                COLLISION_RAW_TOKEN,
                COLLISION_RAW_TOKEN
        );

        createInviteUseCase.createInvite(command(
                owner.id(),
                story.id(),
                INVITE_ID
        ));

        assertThatThrownBy(() -> createInviteUseCase.createInvite(command(
                owner.id(),
                story.id(),
                SECOND_INVITE_ID
        )))
                .isInstanceOf(RuntimeException.class)
                .isNotInstanceOf(InviteCreationUnavailableException.class);

        assertThat(inviteRepository.findById(INVITE_ID)).isPresent();
        assertThat(inviteRepository.findById(SECOND_INVITE_ID)).isEmpty();
        assertThat(inviteCount()).isEqualTo(1);
    }

    @Test
    void shouldRollbackInviteInsertWhenLinkFactoryFailsAfterSave() {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        Story story = saveStory(
                STORY_ID,
                owner.id(),
                "Our Story",
                "The beginning"
        );
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        failingInviteLinkFactory.failOnCreate(
                new RuntimeException("invite link failed")
        );

        assertThatThrownBy(() -> createInviteUseCase.createInvite(command(
                owner.id(),
                story.id(),
                INVITE_ID
        )))
                .isInstanceOf(RuntimeException.class)
                .hasMessage("invite link failed");

        assertThat(inviteRepository.findById(INVITE_ID)).isEmpty();
        assertThat(inviteCount()).isZero();
    }

    private void assertDeniedRoleCreatesNoInvite(StoryRole role) {
        User owner = saveUser(OWNER_ID, "owner-google-subject");
        User user = saveUser(USER_ID, "current-google-subject");
        Story story = saveStory(
                STORY_ID,
                owner.id(),
                "Private Story",
                "The beginning"
        );
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        saveParticipant(story.id(), user.id(), role);

        assertInviteUnavailable(() -> createInviteUseCase.createInvite(
                command(user.id(), story.id(), INVITE_ID)
        ));

        assertThat(inviteCount()).isZero();
    }

    private User saveUser(
            UUID userId,
            String googleSubject
    ) {
        return userRepository.save(
                new User(
                        userId,
                        googleSubject,
                        "Memory Map User",
                        null,
                        BASE_TIME,
                        BASE_TIME
                )
        );
    }

    private Story saveStory(
            UUID storyId,
            UUID ownerId,
            String title,
            String description
    ) {
        return storyRepository.save(
                new Story(
                        storyId,
                        ownerId,
                        title,
                        description,
                        null,
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
        storyParticipantRepository.save(
                new StoryParticipant(
                        storyId,
                        userId,
                        role,
                        BASE_TIME
                )
        );
    }

    private static CreateInviteCommand command(
            UUID userId,
            UUID storyId,
            UUID inviteId
    ) {
        return new CreateInviteCommand(
                new AuthenticatedUser(userId),
                storyId,
                inviteId,
                CURRENT_TIME
        );
    }

    private static String rawTokenFrom(URI inviteLink) {
        return inviteLink.getPath().substring("/invite/".length());
    }

    private int inviteCount() {
        return jdbcClient.sql("""
                SELECT COUNT(*)
                FROM invites
                """)
                .query(Integer.class)
                .single();
    }

    private int inviteCountByTokenHash(String tokenHash) {
        return jdbcClient.sql("""
                SELECT COUNT(*)
                FROM invites
                WHERE token_hash = :tokenHash
                """)
                .param("tokenHash", tokenHash)
                .query(Integer.class)
                .single();
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

    @TestConfiguration(proxyBeanMethods = false)
    static class CreateInviteUseCaseTestConfiguration {

        @Bean
        @Primary
        DeterministicInviteTokenGenerator deterministicInviteTokenGenerator() {
            return new DeterministicInviteTokenGenerator();
        }

        @Bean
        @Primary
        FailingInviteLinkFactory failingInviteLinkFactory(
                InviteProperties inviteProperties,
                JdbcClient jdbcClient
        ) {
            return new FailingInviteLinkFactory(
                    new DefaultInviteLinkFactory(inviteProperties),
                    jdbcClient
            );
        }
    }

    static final class DeterministicInviteTokenGenerator
            implements InviteTokenGenerator {

        private final Queue<String> tokens = new ArrayDeque<>();

        @Override
        public String generate() {
            return tokens.remove();
        }

        private void useTokens(String... rawTokens) {
            tokens.clear();
            tokens.addAll(List.of(rawTokens));
        }

        private void reset() {
            useTokens(FIRST_RAW_TOKEN);
        }
    }

    static final class FailingInviteLinkFactory
            implements InviteLinkFactory {

        private final InviteLinkFactory delegate;
        private final JdbcClient jdbcClient;
        private RuntimeException failure;

        private FailingInviteLinkFactory(
                InviteLinkFactory delegate,
                JdbcClient jdbcClient
        ) {
            this.delegate = delegate;
            this.jdbcClient = jdbcClient;
        }

        @Override
        public URI create(String rawToken) {
            if (failure != null) {
                assertThat(inviteCountInCurrentTransaction())
                        .isEqualTo(1);
                throw failure;
            }

            return delegate.create(rawToken);
        }

        private void failOnCreate(RuntimeException failure) {
            this.failure = failure;
        }

        private void reset() {
            failure = null;
        }

        private int inviteCountInCurrentTransaction() {
            return jdbcClient.sql("""
                    SELECT COUNT(*)
                    FROM invites
                    """)
                    .query(Integer.class)
                    .single();
        }
    }

    @FunctionalInterface
    private interface ThrowingAction {

        void run();
    }
}
