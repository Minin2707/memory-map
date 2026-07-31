package memory_map.backend.story.repository;

import memory_map.backend.IntegrationTest;
import memory_map.backend.story.application.UserStory;
import memory_map.backend.story.domain.Story;
import memory_map.backend.storyparticipant.domain.StoryParticipant;
import memory_map.backend.storyparticipant.domain.StoryRole;
import memory_map.backend.storyparticipant.repository.StoryParticipantRepository;
import memory_map.backend.user.domain.User;
import memory_map.backend.user.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.simple.JdbcClient;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class JdbcUserStoryRepositoryTest extends IntegrationTest {

    @Autowired
    private UserStoryRepository repository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private StoryRepository storyRepository;

    @Autowired
    private StoryParticipantRepository storyParticipantRepository;

    @Autowired
    private JdbcClient jdbcClient;

    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID OTHER_USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000002");
    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000011");
    private static final UUID OTHER_STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000012");
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

    @Test
    void shouldFindUserStoryWhenMembershipMatches() {

        User user = saveUser(USER_ID, "current-google-subject");
        Story story = saveStory(
                STORY_ID,
                user.id(),
                "Our Story",
                "The beginning"
        );
        saveParticipant(story.id(), user.id(), StoryRole.OWNER);

        Optional<UserStory> found =
                repository.findByStoryIdAndUserId(story.id(), user.id());

        assertThat(found)
                .contains(new UserStory(story, StoryRole.OWNER));
    }

    @ParameterizedTest
    @EnumSource(StoryRole.class)
    void shouldFindUserStoryForEveryRole(StoryRole role) {

        User owner = saveUser(OTHER_USER_ID, "owner-google-subject");
        User user = saveUser(USER_ID, "current-google-subject");
        Story story = saveStory(
                STORY_ID,
                owner.id(),
                "Role Story",
                "The beginning"
        );
        saveParticipant(story.id(), user.id(), role);

        Optional<UserStory> found =
                repository.findByStoryIdAndUserId(story.id(), user.id());

        assertThat(found)
                .contains(new UserStory(story, role));
    }

    @Test
    void shouldReturnEmptyWhenStoryDoesNotExist() {

        User user = saveUser(USER_ID, "current-google-subject");

        Optional<UserStory> found =
                repository.findByStoryIdAndUserId(STORY_ID, user.id());

        assertThat(found).isEmpty();
    }

    @Test
    void shouldReturnEmptyWhenStoryExistsWithoutMembership() {

        User owner = saveUser(OTHER_USER_ID, "owner-google-subject");
        User user = saveUser(USER_ID, "current-google-subject");
        Story story = saveStory(
                STORY_ID,
                owner.id(),
                "Private Story",
                "The beginning"
        );

        Optional<UserStory> found =
                repository.findByStoryIdAndUserId(story.id(), user.id());

        assertThat(found).isEmpty();
    }

    @Test
    void shouldReturnEmptyWhenMembershipBelongsToAnotherUser() {

        User owner = saveUser(OTHER_USER_ID, "owner-google-subject");
        User user = saveUser(USER_ID, "current-google-subject");
        Story story = saveStory(
                STORY_ID,
                owner.id(),
                "Other Membership Story",
                "The beginning"
        );
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);

        Optional<UserStory> found =
                repository.findByStoryIdAndUserId(story.id(), user.id());

        assertThat(found).isEmpty();
    }

    @Test
    void shouldUseExactStoryAndUserPair() {

        User user = saveUser(USER_ID, "current-google-subject");
        User otherUser = saveUser(OTHER_USER_ID, "other-google-subject");
        Story story = saveStory(
                STORY_ID,
                user.id(),
                "Current Story",
                "The beginning"
        );
        Story otherStory = saveStory(
                OTHER_STORY_ID,
                otherUser.id(),
                "Other Story",
                "The beginning"
        );
        saveParticipant(story.id(), user.id(), StoryRole.EDITOR);
        saveParticipant(otherStory.id(), otherUser.id(), StoryRole.VIEWER);

        Optional<UserStory> found =
                repository.findByStoryIdAndUserId(story.id(), user.id());
        Optional<UserStory> crossed =
                repository.findByStoryIdAndUserId(
                        story.id(),
                        otherUser.id()
                );

        assertThat(found)
                .contains(new UserStory(story, StoryRole.EDITOR));
        assertThat(crossed).isEmpty();
    }

    @Test
    void shouldMapNullableDescription() {

        User user = saveUser(USER_ID, "current-google-subject");
        Story story = saveStory(
                STORY_ID,
                user.id(),
                "Nullable Description Story",
                null
        );
        saveParticipant(story.id(), user.id(), StoryRole.VIEWER);

        Optional<UserStory> found =
                repository.findByStoryIdAndUserId(story.id(), user.id());

        assertThat(found)
                .contains(new UserStory(story, StoryRole.VIEWER));
        assertThat(found.orElseThrow().story().description()).isNull();
    }

    @Test
    void shouldRejectNullStoryId() {

        assertThatThrownBy(() -> repository.findByStoryIdAndUserId(
                null,
                USER_ID
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("storyId must not be null");
    }

    @Test
    void shouldRejectNullUserId() {

        assertThatThrownBy(() -> repository.findByStoryIdAndUserId(
                STORY_ID,
                null
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("userId must not be null");
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
}
