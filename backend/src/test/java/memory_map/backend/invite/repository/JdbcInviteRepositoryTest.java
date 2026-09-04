package memory_map.backend.invite.repository;

import memory_map.backend.IntegrationTest;
import memory_map.backend.common.database.DatabaseTimestamps;
import memory_map.backend.invite.domain.Invite;
import memory_map.backend.story.domain.Story;
import memory_map.backend.story.repository.StoryRepository;
import memory_map.backend.storyparticipant.domain.StoryRole;
import memory_map.backend.user.domain.User;
import memory_map.backend.user.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class JdbcInviteRepositoryTest extends IntegrationTest {

    @Autowired
    private InviteRepository repository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private StoryRepository storyRepository;

    @Autowired
    private JdbcClient jdbcClient;

    @Autowired
    private PlatformTransactionManager transactionManager;

    private static final Instant BASE_TIME =
            Instant.parse("2026-01-01T10:00:00.123456Z");

    private static final Instant EXPIRES_AT =
            BASE_TIME.plusSeconds(30L * 24 * 60 * 60);

    private static final String CLEAN_DATABASE_SQL = """
        TRUNCATE TABLE users
        RESTART IDENTITY CASCADE
        """;

    @BeforeEach
    void cleanDatabase() {
        jdbcClient.sql(CLEAN_DATABASE_SQL).update();
    }

    private User createUser(String googleSubject) {
        return new User(
                UUID.randomUUID(),
                googleSubject,
                "Konstantin",
                null,
                BASE_TIME,
                BASE_TIME
        );
    }

    private User saveUser(String googleSubject) {
        return userRepository.save(
                createUser(googleSubject)
        );
    }

    private Story createStory(UUID ownerId) {
        return new Story(
                UUID.randomUUID(),
                ownerId,
                "Our Story",
                "The beginning of our journey",
                null,
                BASE_TIME,
                BASE_TIME
        );
    }

    private Story saveStory(User owner) {
        return storyRepository.save(
                createStory(owner.id())
        );
    }

    private Invite createInvite(
            UUID storyId,
            UUID createdBy,
            String tokenHash
    ) {
        return createInvite(
                UUID.randomUUID(),
                storyId,
                tokenHash,
                StoryRole.CO_OWNER,
                createdBy,
                BASE_TIME,
                EXPIRES_AT,
                null
        );
    }

    private Invite createInvite(
            UUID id,
            UUID storyId,
            String tokenHash,
            UUID createdBy,
            Instant createdAt,
            Instant expiresAt,
            Instant usedAt
    ) {
        return createInvite(
                id,
                storyId,
                tokenHash,
                StoryRole.CO_OWNER,
                createdBy,
                createdAt,
                expiresAt,
                usedAt
        );
    }

    private Invite createInvite(
            UUID id,
            UUID storyId,
            String tokenHash,
            StoryRole role,
            UUID createdBy,
            Instant createdAt,
            Instant expiresAt,
            Instant usedAt
    ) {
        return new Invite(
                id,
                storyId,
                role,
                tokenHash,
                createdBy,
                createdAt,
                expiresAt,
                usedAt
        );
    }

    private Invite createUsedInvite(
            UUID storyId,
            UUID createdBy,
            String tokenHash
    ) {
        return createInvite(
                UUID.randomUUID(),
                storyId,
                tokenHash,
                createdBy,
                BASE_TIME,
                EXPIRES_AT,
                BASE_TIME.plusSeconds(60)
        );
    }

    private Story saveStory(String googleSubject) {
        User user = saveUser(googleSubject);

        return saveStory(user);
    }

    private void assertInviteMatches(
            Invite actual,
            Invite expected
    ) {
        assertThat(actual.id()).isEqualTo(expected.id());
        assertThat(actual.storyId()).isEqualTo(expected.storyId());
        assertThat(actual.role()).isEqualTo(expected.role());
        assertThat(actual.tokenHash()).isEqualTo(expected.tokenHash());
        assertThat(actual.createdBy()).isEqualTo(expected.createdBy());
        assertThat(actual.createdAt()).isEqualTo(expected.createdAt());
        assertThat(actual.expiresAt()).isEqualTo(expected.expiresAt());
        assertThat(actual.usedAt()).isEqualTo(expected.usedAt());
    }

    @Test
    void shouldSaveAndFindInviteById() {

        User user = saveUser("google-subject-123");
        Story story = saveStory(user);
        Invite invite = createInvite(
                story.id(),
                user.id(),
                "hash-invite-001"
        );

        repository.save(invite);

        Invite loaded = repository.findById(invite.id())
                .orElseThrow();

        assertInviteMatches(loaded, invite);
    }

    @ParameterizedTest
    @EnumSource(value = StoryRole.class, names = {
            "CO_OWNER",
            "EDITOR",
            "VIEWER"
    })
    void shouldRoundTripInviteRole(StoryRole role) {

        User user = saveUser("google-subject-123");
        Story story = saveStory(user);
        Invite invite = createInvite(
                UUID.randomUUID(),
                story.id(),
                "hash-invite-" + role.name(),
                role,
                user.id(),
                BASE_TIME,
                EXPIRES_AT,
                null
        );

        repository.save(invite);

        assertThat(repository.findById(invite.id()))
                .contains(invite);
    }

    @Test
    void shouldFindInviteByTokenHash() {

        User user = saveUser("google-subject-123");
        Story story = saveStory(user);
        Invite first = createInvite(
                story.id(),
                user.id(),
                "hash-invite-001"
        );
        Invite second = createInvite(
                story.id(),
                user.id(),
                "hash-invite-002"
        );

        repository.save(first);
        repository.save(second);

        Optional<Invite> found =
                repository.findByTokenHash(first.tokenHash());

        assertThat(found)
                .contains(first);

        assertThat(repository.findByTokenHash("hash-invite-missing"))
                .isEmpty();
    }

    @Test
    void shouldFindInviteByTokenHashForUpdate() {

        User user = saveUser("google-subject-123");
        Story story = saveStory(user);
        Invite invite = createInvite(
                story.id(),
                user.id(),
                "hash-invite-001"
        );

        repository.save(invite);

        Optional<Invite> found =
                repository.findByTokenHashForUpdate(invite.tokenHash());

        assertThat(found).contains(invite);
    }

    @Test
    void shouldReturnEmptyWhenInviteTokenHashDoesNotExistForUpdate() {

        Optional<Invite> found =
                repository.findByTokenHashForUpdate("hash-invite-missing");

        assertThat(found).isEmpty();
    }

    @Test
    void shouldFindUsedInviteByTokenHashForUpdate() {

        User user = saveUser("google-subject-123");
        Story story = saveStory(user);
        Invite invite = createUsedInvite(
                story.id(),
                user.id(),
                "hash-invite-001"
        );

        repository.save(invite);

        Optional<Invite> found =
                repository.findByTokenHashForUpdate(invite.tokenHash());

        assertThat(found).contains(invite);
    }

    @Test
    void shouldFindExpiredInviteByTokenHashForUpdate() {

        User user = saveUser("google-subject-123");
        Story story = saveStory(user);
        Invite invite = createInvite(
                UUID.randomUUID(),
                story.id(),
                "hash-invite-001",
                user.id(),
                Instant.parse("2025-01-01T10:00:00Z"),
                Instant.parse("2025-01-02T10:00:00Z"),
                null
        );

        repository.save(invite);

        Optional<Invite> found =
                repository.findByTokenHashForUpdate(invite.tokenHash());

        assertThat(found).contains(invite);
    }

    @Test
    void shouldNotModifyInviteWhenFindingByTokenHashForUpdate() {

        User user = saveUser("google-subject-123");
        Story story = saveStory(user);
        Invite invite = createInvite(
                story.id(),
                user.id(),
                "hash-invite-001"
        );

        repository.save(invite);

        repository.findByTokenHashForUpdate(invite.tokenHash());

        Invite loaded = repository.findById(invite.id())
                .orElseThrow();

        assertInviteMatches(loaded, invite);
    }

    @Test
    void shouldRejectNullTokenHashWhenFindingByTokenHashForUpdate() {

        assertThatThrownBy(() -> repository.findByTokenHashForUpdate(null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("tokenHash must not be null");
    }

    @Test
    void shouldReturnEmptyWhenInviteDoesNotExist() {

        Optional<Invite> found =
                repository.findById(UUID.randomUUID());

        assertThat(found).isEmpty();
    }

    @Test
    void shouldFindInvitesByStoryId() {

        User firstUser = saveUser("first-google-subject");
        Story firstStory = saveStory(firstUser);
        Story secondStory = saveStory("second-google-subject");
        Invite first = createInvite(
                firstStory.id(),
                firstUser.id(),
                "hash-invite-001"
        );
        Invite second = createInvite(
                UUID.randomUUID(),
                firstStory.id(),
                "hash-invite-002",
                firstUser.id(),
                BASE_TIME.plusSeconds(1),
                EXPIRES_AT.plusSeconds(1),
                null
        );
        Invite other = createInvite(
                secondStory.id(),
                firstUser.id(),
                "hash-invite-003"
        );

        repository.save(first);
        repository.save(second);
        repository.save(other);

        List<Invite> invites =
                repository.findByStoryId(firstStory.id());

        assertThat(invites)
                .containsExactly(first, second);
    }

    @Test
    void shouldFindInvitesByStoryIdSortedByCreatedAtAndId() {

        User user = saveUser("google-subject-123");
        Story story = saveStory(user);
        Invite earliest = createInvite(
                UUID.fromString("00000000-0000-0000-0000-000000000003"),
                story.id(),
                "hash-invite-earliest",
                user.id(),
                BASE_TIME.plusSeconds(1),
                EXPIRES_AT.plusSeconds(1),
                null
        );
        Invite firstById = createInvite(
                UUID.fromString("00000000-0000-0000-0000-000000000001"),
                story.id(),
                "hash-invite-first-by-id",
                user.id(),
                BASE_TIME.plusSeconds(2),
                EXPIRES_AT.plusSeconds(2),
                null
        );
        Invite secondById = createInvite(
                UUID.fromString("00000000-0000-0000-0000-000000000002"),
                story.id(),
                "hash-invite-second-by-id",
                user.id(),
                BASE_TIME.plusSeconds(2),
                EXPIRES_AT.plusSeconds(2),
                null
        );

        repository.save(secondById);
        repository.save(firstById);
        repository.save(earliest);

        List<Invite> invites =
                repository.findByStoryId(story.id());

        assertThat(invites)
                .extracting(Invite::id)
                .containsExactly(
                        earliest.id(),
                        firstById.id(),
                        secondById.id()
                );
    }

    @Test
    void shouldPreserveNullableUsedAt() {

        User user = saveUser("google-subject-123");
        Story story = saveStory(user);
        Invite invite = createInvite(
                story.id(),
                user.id(),
                "hash-invite-001"
        );

        repository.save(invite);

        Invite loaded = repository.findById(invite.id())
                .orElseThrow();

        assertThat(loaded.usedAt()).isNull();
    }

    @Test
    void shouldSaveUsedInvite() {

        User user = saveUser("google-subject-123");
        Story story = saveStory(user);
        Invite invite = createUsedInvite(
                story.id(),
                user.id(),
                "hash-invite-001"
        );

        repository.save(invite);

        Invite loaded = repository.findById(invite.id())
                .orElseThrow();

        assertInviteMatches(loaded, invite);
    }

    @Test
    void shouldMarkInviteUsedIfUnused() {

        User user = saveUser("google-subject-123");
        Story story = saveStory(user);
        Invite invite = createInvite(
                story.id(),
                user.id(),
                "hash-invite-001"
        );
        Instant usedAt = BASE_TIME.plusSeconds(60);

        repository.save(invite);

        boolean marked = repository.markUsedIfUnused(
                invite.id(),
                usedAt
        );

        Invite loaded = repository.findById(invite.id())
                .orElseThrow();

        assertThat(marked).isTrue();
        assertInviteMatches(
                loaded,
                createInvite(
                        invite.id(),
                        invite.storyId(),
                        invite.tokenHash(),
                        invite.role(),
                        invite.createdBy(),
                        invite.createdAt(),
                        invite.expiresAt(),
                        usedAt
                )
        );
    }

    @Test
    void shouldReturnFalseWhenInviteDoesNotExistForMarkUsedIfUnused() {

        boolean marked = repository.markUsedIfUnused(
                UUID.randomUUID(),
                BASE_TIME.plusSeconds(60)
        );

        assertThat(marked).isFalse();
    }

    @Test
    void shouldReturnFalseWhenInviteIsAlreadyUsed() {

        User user = saveUser("google-subject-123");
        Story story = saveStory(user);
        Invite invite = createUsedInvite(
                story.id(),
                user.id(),
                "hash-invite-001"
        );

        repository.save(invite);

        boolean marked = repository.markUsedIfUnused(
                invite.id(),
                BASE_TIME.plusSeconds(120)
        );

        Invite loaded = repository.findById(invite.id())
                .orElseThrow();

        assertThat(marked).isFalse();
        assertInviteMatches(loaded, invite);
    }

    @Test
    void shouldPreserveFirstUsedAtWhenSecondMarkUsedFails() {

        User user = saveUser("google-subject-123");
        Story story = saveStory(user);
        Invite invite = createInvite(
                story.id(),
                user.id(),
                "hash-invite-001"
        );
        Instant firstUsedAt = BASE_TIME.plusSeconds(60);
        Instant secondUsedAt = BASE_TIME.plusSeconds(120);

        repository.save(invite);

        boolean first = repository.markUsedIfUnused(
                invite.id(),
                firstUsedAt
        );
        boolean second = repository.markUsedIfUnused(
                invite.id(),
                secondUsedAt
        );

        Invite loaded = repository.findById(invite.id())
                .orElseThrow();

        assertThat(first).isTrue();
        assertThat(second).isFalse();
        assertThat(loaded.role()).isEqualTo(invite.role());
        assertThat(loaded.usedAt()).isEqualTo(firstUsedAt);
    }

    @Test
    void shouldMarkOnlySpecifiedInviteUsed() {

        User user = saveUser("google-subject-123");
        Story story = saveStory(user);
        Invite first = createInvite(
                story.id(),
                user.id(),
                "hash-invite-001"
        );
        Invite second = createInvite(
                story.id(),
                user.id(),
                "hash-invite-002"
        );
        Instant usedAt = BASE_TIME.plusSeconds(60);

        repository.save(first);
        repository.save(second);

        boolean marked = repository.markUsedIfUnused(
                first.id(),
                usedAt
        );

        Invite loadedFirst = repository.findById(first.id())
                .orElseThrow();
        Invite loadedSecond = repository.findById(second.id())
                .orElseThrow();

        assertThat(marked).isTrue();
        assertThat(loadedFirst.usedAt()).isEqualTo(usedAt);
        assertThat(loadedSecond.usedAt()).isNull();
    }

    @Test
    void shouldRejectNullInviteIdWhenMarkingUsedIfUnused() {

        assertThatThrownBy(() -> repository.markUsedIfUnused(
                null,
                BASE_TIME.plusSeconds(60)
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("inviteId must not be null");
    }

    @Test
    void shouldRejectNullUsedAtWhenMarkingUsedIfUnused() {

        assertThatThrownBy(() -> repository.markUsedIfUnused(
                UUID.randomUUID(),
                null
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("usedAt must not be null");
    }

    @Test
    void shouldRollBackMarkUsedIfUnusedInOuterTransaction() {

        User user = saveUser("google-subject-123");
        Story story = saveStory(user);
        Invite invite = createInvite(
                story.id(),
                user.id(),
                "hash-invite-001"
        );
        TransactionTemplate transactionTemplate =
                new TransactionTemplate(transactionManager);

        repository.save(invite);

        Boolean marked = transactionTemplate.execute(status -> {
            boolean result = repository.markUsedIfUnused(
                    invite.id(),
                    BASE_TIME.plusSeconds(60)
            );

            status.setRollbackOnly();
            return result;
        });

        Invite loaded = repository.findById(invite.id())
                .orElseThrow();

        assertThat(marked).isTrue();
        assertThat(loaded.role()).isEqualTo(invite.role());
        assertThat(loaded.usedAt()).isNull();
    }

    @Test
    void shouldDeleteInvite() {

        User user = saveUser("google-subject-123");
        Story story = saveStory(user);
        Invite first = createInvite(
                story.id(),
                user.id(),
                "hash-invite-001"
        );
        Invite second = createInvite(
                story.id(),
                user.id(),
                "hash-invite-002"
        );

        repository.save(first);
        repository.save(second);

        repository.delete(first.id());

        assertThat(repository.findById(first.id()))
                .isEmpty();

        assertThat(repository.findById(second.id()))
                .contains(second);
    }

    @Test
    void shouldRejectDuplicateInviteId() {

        User user = saveUser("google-subject-123");
        Story story = saveStory(user);
        UUID inviteId = UUID.randomUUID();
        Invite first = createInvite(
                inviteId,
                story.id(),
                "hash-invite-001",
                StoryRole.CO_OWNER,
                user.id(),
                BASE_TIME,
                EXPIRES_AT,
                null
        );
        Invite second = createInvite(
                inviteId,
                story.id(),
                "hash-invite-002",
                StoryRole.CO_OWNER,
                user.id(),
                BASE_TIME,
                EXPIRES_AT,
                null
        );

        repository.save(first);

        assertThatThrownBy(() -> repository.save(second))
                .isInstanceOf(DuplicateKeyException.class);
    }

    @Test
    void shouldRejectDuplicateTokenHash() {

        User user = saveUser("google-subject-123");
        Story story = saveStory(user);
        Invite first = createInvite(
                story.id(),
                user.id(),
                "hash-invite-001"
        );
        Invite second = createInvite(
                story.id(),
                user.id(),
                "hash-invite-001"
        );

        repository.save(first);

        assertThatThrownBy(() -> repository.save(second))
                .isInstanceOf(DuplicateKeyException.class);
    }

    @Test
    void shouldRejectOwnerInviteRoleAtDatabaseBoundary() {

        User user = saveUser("google-subject-123");
        Story story = saveStory(user);

        assertThatThrownBy(() -> jdbcClient.sql("""
                        INSERT INTO invites (
                            id,
                            story_id,
                            role,
                            token_hash,
                            created_by,
                            created_at,
                            expires_at,
                            used_at
                        )
                        VALUES (
                            :id,
                            :storyId,
                            :role,
                            :tokenHash,
                            :createdBy,
                            :createdAt,
                            :expiresAt,
                            NULL
                        )
                        """)
                .param("id", UUID.randomUUID())
                .param("storyId", story.id())
                .param("role", StoryRole.OWNER.name())
                .param("tokenHash", "hash-owner-role")
                .param("createdBy", user.id())
                .param(
                        "createdAt",
                        DatabaseTimestamps.toOffsetDateTime(BASE_TIME)
                )
                .param(
                        "expiresAt",
                        DatabaseTimestamps.toOffsetDateTime(EXPIRES_AT)
                )
                .update())
                .isInstanceOf(DataIntegrityViolationException.class);
    }

    @Test
    void shouldRejectInviteWithUnknownStory() {

        User user = saveUser("google-subject-123");
        Invite invite = createInvite(
                UUID.randomUUID(),
                user.id(),
                "hash-invite-001"
        );

        assertThatThrownBy(() -> repository.save(invite))
                .isInstanceOf(DataIntegrityViolationException.class);
    }

    @Test
    void shouldRejectInviteWithUnknownCreator() {

        User user = saveUser("google-subject-123");
        Story story = saveStory(user);
        Invite invite = createInvite(
                story.id(),
                UUID.randomUUID(),
                "hash-invite-001"
        );

        assertThatThrownBy(() -> repository.save(invite))
                .isInstanceOf(DataIntegrityViolationException.class);
    }

}
