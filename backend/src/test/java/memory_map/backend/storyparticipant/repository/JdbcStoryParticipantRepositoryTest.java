package memory_map.backend.storyparticipant.repository;

import memory_map.backend.IntegrationTest;
import memory_map.backend.story.domain.Story;
import memory_map.backend.story.repository.StoryRepository;
import memory_map.backend.storyparticipant.domain.StoryParticipant;
import memory_map.backend.storyparticipant.domain.StoryRole;
import memory_map.backend.user.domain.User;
import memory_map.backend.user.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.jdbc.core.simple.JdbcClient;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class JdbcStoryParticipantRepositoryTest extends IntegrationTest {

    @Autowired
    private StoryParticipantRepository repository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private StoryRepository storyRepository;

    @Autowired
    private JdbcClient jdbcClient;

    private static final Instant BASE_TIME =
            Instant.parse("2026-01-01T10:00:00.123456Z");

    private static final String CLEAN_DATABASE_SQL = """
        TRUNCATE TABLE users
        RESTART IDENTITY CASCADE
        """;

    @BeforeEach
    void cleanDatabase() {
        jdbcClient.sql(CLEAN_DATABASE_SQL).update();
    }

    private User createUser(String googleSubject) {
        return createUser(UUID.randomUUID(), googleSubject);
    }

    private User createUser(UUID id, String googleSubject) {
        return new User(
                id,
                googleSubject,
                "Konstantin",
                null,
                BASE_TIME,
                BASE_TIME
        );
    }

    private Story createStory(UUID ownerId) {
        return createStory(UUID.randomUUID(), ownerId);
    }

    private Story createStory(UUID id, UUID ownerId) {
        return new Story(
                id,
                ownerId,
                "Our Story",
                "The beginning of our journey",
                null,
                BASE_TIME,
                BASE_TIME
        );
    }

    private StoryParticipant createParticipant(
            UUID storyId,
            UUID userId,
            StoryRole role,
            Instant joinedAt
    ) {
        return new StoryParticipant(
                storyId,
                userId,
                role,
                joinedAt
        );
    }

    private User saveUser(String googleSubject) {
        return userRepository.save(
                createUser(googleSubject)
        );
    }

    private User saveUser(UUID id, String googleSubject) {
        return userRepository.save(
                createUser(id, googleSubject)
        );
    }

    private Story saveStory(User owner) {
        return storyRepository.save(
                createStory(owner.id())
        );
    }

    private Story saveStory(UUID id, User owner) {
        return storyRepository.save(
                createStory(id, owner.id())
        );
    }

    @Test
    void shouldSaveAndFindStoryParticipant() {

        User user = saveUser("google-subject-123");
        Story story = saveStory(user);

        StoryParticipant participant = createParticipant(
                story.id(),
                user.id(),
                StoryRole.OWNER,
                BASE_TIME.plusSeconds(1)
        );

        repository.save(participant);

        Optional<StoryParticipant> found =
                repository.find(story.id(), user.id());

        assertThat(found).isPresent();

        assertThat(found.get())
                .isEqualTo(participant);
    }

    @Test
    void shouldReturnEmptyWhenStoryParticipantDoesNotExist() {

        Optional<StoryParticipant> found =
                repository.find(
                        UUID.randomUUID(),
                        UUID.randomUUID()
                );

        assertThat(found).isEmpty();
    }

    @Test
    void shouldFindStoryParticipantsByStoryId() {

        User owner = saveUser("owner-google-subject");
        User firstUser = saveUser(
                UUID.fromString("00000000-0000-0000-0000-000000000002"),
                "first-google-subject"
        );
        User secondUser = saveUser(
                UUID.fromString("00000000-0000-0000-0000-000000000001"),
                "second-google-subject"
        );
        User otherUser = saveUser("other-google-subject");

        Story story = saveStory(owner);
        Story otherStory = saveStory(otherUser);

        StoryParticipant first = createParticipant(
                story.id(),
                firstUser.id(),
                StoryRole.EDITOR,
                BASE_TIME.plusSeconds(2)
        );
        StoryParticipant second = createParticipant(
                story.id(),
                secondUser.id(),
                StoryRole.VIEWER,
                BASE_TIME.plusSeconds(1)
        );
        StoryParticipant other = createParticipant(
                otherStory.id(),
                otherUser.id(),
                StoryRole.OWNER,
                BASE_TIME
        );

        repository.save(first);
        repository.save(second);
        repository.save(other);

        List<StoryParticipant> participants =
                repository.findByStoryId(story.id());

        assertThat(participants)
                .containsExactly(second, first);
    }

    @Test
    void shouldFindStoryParticipantsByStoryIdOrderedByUserIdWhenJoinedAtMatches() {

        User owner = saveUser("owner-google-subject");
        User firstUser = saveUser(
                UUID.fromString("00000000-0000-0000-0000-000000000001"),
                "first-google-subject"
        );
        User secondUser = saveUser(
                UUID.fromString("00000000-0000-0000-0000-000000000002"),
                "second-google-subject"
        );

        Story story = saveStory(owner);

        StoryParticipant first = createParticipant(
                story.id(),
                firstUser.id(),
                StoryRole.EDITOR,
                BASE_TIME
        );
        StoryParticipant second = createParticipant(
                story.id(),
                secondUser.id(),
                StoryRole.VIEWER,
                BASE_TIME
        );

        repository.save(second);
        repository.save(first);

        List<StoryParticipant> participants =
                repository.findByStoryId(story.id());

        assertThat(participants)
                .containsExactly(first, second);
    }

    @Test
    void shouldFindStoryParticipantsByUserId() {

        User user = saveUser("google-subject-123");
        User firstOwner = saveUser("first-owner-google-subject");
        User secondOwner = saveUser("second-owner-google-subject");
        User otherUser = saveUser("other-google-subject");

        Story firstStory = saveStory(firstOwner);
        Story secondStory = saveStory(secondOwner);
        Story otherStory = saveStory(otherUser);

        StoryParticipant first = createParticipant(
                firstStory.id(),
                user.id(),
                StoryRole.EDITOR,
                BASE_TIME.plusSeconds(2)
        );
        StoryParticipant second = createParticipant(
                secondStory.id(),
                user.id(),
                StoryRole.VIEWER,
                BASE_TIME.plusSeconds(1)
        );
        StoryParticipant other = createParticipant(
                otherStory.id(),
                otherUser.id(),
                StoryRole.OWNER,
                BASE_TIME
        );

        repository.save(first);
        repository.save(second);
        repository.save(other);

        List<StoryParticipant> participants =
                repository.findByUserId(user.id());

        assertThat(participants)
                .containsExactly(second, first);
    }

    @Test
    void shouldFindStoryParticipantsByUserIdOrderedByStoryIdWhenJoinedAtMatches() {

        User user = saveUser("google-subject-123");
        User owner = saveUser("owner-google-subject");

        Story firstStory = saveStory(
                UUID.fromString("00000000-0000-0000-0000-000000000001"),
                owner
        );
        Story secondStory = saveStory(
                UUID.fromString("00000000-0000-0000-0000-000000000002"),
                owner
        );

        StoryParticipant first = createParticipant(
                firstStory.id(),
                user.id(),
                StoryRole.EDITOR,
                BASE_TIME
        );
        StoryParticipant second = createParticipant(
                secondStory.id(),
                user.id(),
                StoryRole.VIEWER,
                BASE_TIME
        );

        repository.save(second);
        repository.save(first);

        List<StoryParticipant> participants =
                repository.findByUserId(user.id());

        assertThat(participants)
                .containsExactly(first, second);
    }

    @Test
    void shouldCountOwnersByStoryId() {

        User owner = saveUser("owner-google-subject");
        User secondOwner = saveUser("second-owner-google-subject");
        User coOwner = saveUser("co-owner-google-subject");
        User editor = saveUser("editor-google-subject");
        User otherOwner = saveUser("other-owner-google-subject");
        Story story = saveStory(owner);
        Story otherStory = saveStory(otherOwner);

        repository.save(createParticipant(
                story.id(),
                owner.id(),
                StoryRole.OWNER,
                BASE_TIME
        ));
        repository.save(createParticipant(
                story.id(),
                secondOwner.id(),
                StoryRole.OWNER,
                BASE_TIME.plusSeconds(1)
        ));
        repository.save(createParticipant(
                story.id(),
                coOwner.id(),
                StoryRole.CO_OWNER,
                BASE_TIME.plusSeconds(2)
        ));
        repository.save(createParticipant(
                story.id(),
                editor.id(),
                StoryRole.EDITOR,
                BASE_TIME.plusSeconds(3)
        ));
        repository.save(createParticipant(
                otherStory.id(),
                otherOwner.id(),
                StoryRole.OWNER,
                BASE_TIME
        ));

        assertThat(repository.countOwners(story.id())).isEqualTo(2);
    }

    @Test
    void shouldReturnZeroWhenCountingOwnersForStoryWithoutOwners() {

        User owner = saveUser("owner-google-subject");
        User viewer = saveUser("viewer-google-subject");
        Story story = saveStory(owner);

        repository.save(createParticipant(
                story.id(),
                viewer.id(),
                StoryRole.VIEWER,
                BASE_TIME
        ));

        assertThat(repository.countOwners(story.id())).isZero();
    }

    @Test
    void shouldRejectNullStoryIdWhenCountingOwners() {

        assertThatThrownBy(() -> repository.countOwners(null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("storyId must not be null");
    }

    @Test
    void shouldCheckStoryParticipantExists() {

        User user = saveUser("google-subject-123");
        User otherUser = saveUser("other-google-subject");
        Story story = saveStory(user);
        Story otherStory = saveStory(otherUser);

        StoryParticipant participant = createParticipant(
                story.id(),
                user.id(),
                StoryRole.OWNER,
                BASE_TIME
        );

        repository.save(participant);

        assertThat(repository.exists(story.id(), user.id()))
                .isTrue();

        assertThat(repository.exists(otherStory.id(), otherUser.id()))
                .isFalse();

        assertThat(repository.exists(story.id(), otherUser.id()))
                .isFalse();

        assertThat(repository.exists(otherStory.id(), user.id()))
                .isFalse();
    }

    @Test
    void shouldUpdateStoryParticipantRole() {

        User user = saveUser("google-subject-123");
        Story story = saveStory(user);

        StoryParticipant participant = createParticipant(
                story.id(),
                user.id(),
                StoryRole.EDITOR,
                BASE_TIME
        );
        StoryParticipant updatedParticipant = createParticipant(
                story.id(),
                user.id(),
                StoryRole.CO_OWNER,
                participant.joinedAt()
        );

        repository.save(participant);

        repository.update(updatedParticipant);

        StoryParticipant loaded =
                repository.find(story.id(), user.id())
                        .orElseThrow();

        assertThat(loaded.role()).isEqualTo(StoryRole.CO_OWNER);
        assertThat(loaded.storyId()).isEqualTo(participant.storyId());
        assertThat(loaded.userId()).isEqualTo(participant.userId());
        assertThat(loaded.joinedAt()).isEqualTo(participant.joinedAt());
    }

    @Test
    void shouldDeleteStoryParticipant() {

        User firstUser = saveUser("first-google-subject");
        User secondUser = saveUser("second-google-subject");
        Story story = saveStory(firstUser);

        StoryParticipant first = createParticipant(
                story.id(),
                firstUser.id(),
                StoryRole.OWNER,
                BASE_TIME
        );
        StoryParticipant second = createParticipant(
                story.id(),
                secondUser.id(),
                StoryRole.VIEWER,
                BASE_TIME.plusSeconds(1)
        );

        repository.save(first);
        repository.save(second);

        repository.delete(story.id(), firstUser.id());

        assertThat(repository.find(story.id(), firstUser.id()))
                .isEmpty();

        assertThat(repository.exists(story.id(), firstUser.id()))
                .isFalse();

        assertThat(repository.find(story.id(), secondUser.id()))
                .contains(second);
    }

    @Test
    void shouldRejectDuplicateStoryParticipant() {

        User user = saveUser("google-subject-123");
        Story story = saveStory(user);

        StoryParticipant participant = createParticipant(
                story.id(),
                user.id(),
                StoryRole.OWNER,
                BASE_TIME
        );

        repository.save(participant);

        assertThatThrownBy(() -> repository.save(participant))
                .isInstanceOf(DuplicateKeyException.class);
    }
}
