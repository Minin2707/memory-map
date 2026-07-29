package memory_map.backend.invite.repository;

import memory_map.backend.IntegrationTest;
import memory_map.backend.invite.domain.Invite;
import memory_map.backend.story.domain.Story;
import memory_map.backend.story.repository.StoryRepository;
import memory_map.backend.user.domain.User;
import memory_map.backend.user.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.jdbc.core.simple.JdbcClient;

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
        return new Invite(
                id,
                storyId,
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
    void shouldUpdateUsedAt() {

        User user = saveUser("google-subject-123");
        Story story = saveStory(user);
        Invite invite = createInvite(
                story.id(),
                user.id(),
                "hash-invite-001"
        );
        Invite updatedInvite = createInvite(
                invite.id(),
                invite.storyId(),
                invite.tokenHash(),
                invite.createdBy(),
                invite.createdAt(),
                invite.expiresAt(),
                BASE_TIME.plusSeconds(60)
        );

        repository.save(invite);

        repository.update(updatedInvite);

        Invite loaded = repository.findById(invite.id())
                .orElseThrow();

        assertInviteMatches(loaded, updatedInvite);
    }

    @Test
    void shouldUpdateUsedAtBackToNull() {

        User user = saveUser("google-subject-123");
        Story story = saveStory(user);
        Invite invite = createUsedInvite(
                story.id(),
                user.id(),
                "hash-invite-001"
        );
        Invite updatedInvite = createInvite(
                invite.id(),
                invite.storyId(),
                invite.tokenHash(),
                invite.createdBy(),
                invite.createdAt(),
                invite.expiresAt(),
                null
        );

        repository.save(invite);

        repository.update(updatedInvite);

        Invite loaded = repository.findById(invite.id())
                .orElseThrow();

        assertThat(loaded.usedAt()).isNull();
        assertInviteMatches(loaded, updatedInvite);
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
                user.id(),
                BASE_TIME,
                EXPIRES_AT,
                null
        );
        Invite second = createInvite(
                inviteId,
                story.id(),
                "hash-invite-002",
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
