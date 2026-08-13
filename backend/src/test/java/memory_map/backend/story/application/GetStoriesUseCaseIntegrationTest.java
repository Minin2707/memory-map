package memory_map.backend.story.application;

import memory_map.backend.IntegrationTest;
import memory_map.backend.auth.domain.AuthenticatedUser;
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
import org.springframework.jdbc.core.simple.JdbcClient;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

class GetStoriesUseCaseIntegrationTest extends IntegrationTest {

    @Autowired
    private GetStoriesUseCase getStoriesUseCase;

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
    private static final UUID OWNER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000002");
    private static final UUID OTHER_USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000003");
    private static final UUID OWNER_STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000011");
    private static final UUID EDITOR_STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000012");
    private static final UUID OTHER_STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000013");
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
    void shouldReturnOwnerAndEditorStoriesForAuthenticatedUser() {

        User user = saveUser(USER_ID, "current-google-subject");
        User owner = saveUser(OWNER_ID, "owner-google-subject");
        User other = saveUser(OTHER_USER_ID, "other-google-subject");

        Story ownerStory = saveStory(
                OWNER_STORY_ID,
                user.id(),
                "Owner Story",
                BASE_TIME.plusSeconds(10)
        );
        Story editorStory = saveStory(
                EDITOR_STORY_ID,
                owner.id(),
                "Editor Story",
                BASE_TIME.plusSeconds(20)
        );
        Story otherStory = saveStory(
                OTHER_STORY_ID,
                other.id(),
                "Other Story",
                BASE_TIME.plusSeconds(30)
        );

        saveParticipant(
                ownerStory.id(),
                user.id(),
                StoryRole.OWNER,
                BASE_TIME.plusSeconds(2)
        );
        saveParticipant(
                editorStory.id(),
                owner.id(),
                StoryRole.OWNER,
                BASE_TIME
        );
        saveParticipant(
                editorStory.id(),
                user.id(),
                StoryRole.EDITOR,
                BASE_TIME.plusSeconds(1)
        );
        saveParticipant(
                otherStory.id(),
                other.id(),
                StoryRole.OWNER,
                BASE_TIME.plusSeconds(3)
        );

        List<UserStory> userStories = getStoriesUseCase.getStories(
                new AuthenticatedUser(user.id())
        );

        assertThat(userStories)
                .containsExactly(
                        new UserStory(
                                editorStory,
                                StoryRole.EDITOR,
                                0,
                                2,
                                null
                        ),
                        new UserStory(ownerStory, StoryRole.OWNER)
                );
    }

    @Test
    void shouldReturnEmptyListWhenUserHasNoStories() {

        User user = saveUser(USER_ID, "current-google-subject");
        User other = saveUser(OTHER_USER_ID, "other-google-subject");
        Story otherStory = saveStory(
                OTHER_STORY_ID,
                other.id(),
                "Other Story",
                BASE_TIME
        );
        saveParticipant(
                otherStory.id(),
                other.id(),
                StoryRole.OWNER,
                BASE_TIME
        );

        List<UserStory> userStories = getStoriesUseCase.getStories(
                new AuthenticatedUser(user.id())
        );

        assertThat(userStories).isEmpty();
    }

    @Test
    void shouldOrderStoriesByCurrentUserParticipation() {

        User user = saveUser(USER_ID, "current-google-subject");

        Story firstStory = saveStory(
                EDITOR_STORY_ID,
                user.id(),
                "First Story",
                BASE_TIME
        );
        Story secondStory = saveStory(
                OWNER_STORY_ID,
                user.id(),
                "Second Story",
                BASE_TIME.plusSeconds(1)
        );

        saveParticipant(
                secondStory.id(),
                user.id(),
                StoryRole.OWNER,
                BASE_TIME.plusSeconds(2)
        );
        saveParticipant(
                firstStory.id(),
                user.id(),
                StoryRole.VIEWER,
                BASE_TIME.plusSeconds(1)
        );

        List<UserStory> userStories = getStoriesUseCase.getStories(
                new AuthenticatedUser(user.id())
        );

        assertThat(userStories)
                .containsExactly(
                        new UserStory(firstStory, StoryRole.VIEWER),
                        new UserStory(secondStory, StoryRole.OWNER)
                );
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
            Instant currentTime
    ) {
        return storyRepository.save(
                new Story(
                        storyId,
                        ownerId,
                        title,
                        "The beginning",
                        currentTime,
                        currentTime
                )
        );
    }

    private void saveParticipant(
            UUID storyId,
            UUID userId,
            StoryRole role,
            Instant joinedAt
    ) {
        storyParticipantRepository.save(
                new StoryParticipant(
                        storyId,
                        userId,
                        role,
                        joinedAt
                )
        );
    }
}
