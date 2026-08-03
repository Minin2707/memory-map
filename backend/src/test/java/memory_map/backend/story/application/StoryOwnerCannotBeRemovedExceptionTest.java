package memory_map.backend.story.application;

import memory_map.backend.storyparticipant.domain.StoryRole;
import org.junit.jupiter.api.Test;

import java.lang.reflect.Constructor;
import java.util.Arrays;
import java.util.Locale;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

class StoryOwnerCannotBeRemovedExceptionTest {

    private static final String SAFE_MESSAGE =
            "A story owner cannot be removed";
    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID ACTOR_USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000002");
    private static final UUID TARGET_USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000003");

    @Test
    void shouldCreateExceptionWithSafeMessage() {

        StoryOwnerCannotBeRemovedException exception =
                new StoryOwnerCannotBeRemovedException();

        assertThat(exception)
                .hasMessage(SAFE_MESSAGE)
                .hasNoCause();
    }

    @Test
    void shouldUseStableSafeMessageAndToString() {

        StoryOwnerCannotBeRemovedException exception =
                new StoryOwnerCannotBeRemovedException();

        assertThat(exception.getMessage()).isEqualTo(SAFE_MESSAGE);
        assertThat(exception.toString())
                .isEqualTo(
                        StoryOwnerCannotBeRemovedException.class.getName()
                                + ": "
                                + SAFE_MESSAGE
                );
    }

    @Test
    void shouldNotExposeIdentifiersCountsRolesOrInfrastructureDetails() {

        StoryOwnerCannotBeRemovedException exception =
                new StoryOwnerCannotBeRemovedException();

        assertSafeText(exception.getMessage());
        assertSafeText(exception.toString());
    }

    @Test
    void shouldExposeOnlySafeNoArgumentConstructor() {

        assertThat(Arrays.stream(StoryOwnerCannotBeRemovedException.class
                .getConstructors())
                .map(Constructor::getParameterCount))
                .containsExactly(0);
    }

    private static void assertSafeText(String text) {
        assertThat(text)
                .doesNotContain(STORY_ID.toString())
                .doesNotContain(ACTOR_USER_ID.toString())
                .doesNotContain(TARGET_USER_ID.toString())
                .doesNotContain(StoryRole.OWNER.name())
                .doesNotContain(StoryRole.CO_OWNER.name())
                .doesNotContain(StoryRole.EDITOR.name())
                .doesNotContain(StoryRole.VIEWER.name())
                .doesNotContain("0")
                .doesNotContain("1")
                .doesNotContain("2");

        assertThat(text.toLowerCase(Locale.ROOT))
                .doesNotContain("userid")
                .doesNotContain("storyid")
                .doesNotContain("actor")
                .doesNotContain("target")
                .doesNotContain("count")
                .doesNotContain("sql")
                .doesNotContain("jdbc")
                .doesNotContain("repository")
                .doesNotContain("http")
                .doesNotContain("status")
                .doesNotContain("token")
                .doesNotContain("auth");
    }
}
