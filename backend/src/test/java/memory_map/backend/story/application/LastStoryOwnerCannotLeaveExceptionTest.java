package memory_map.backend.story.application;

import org.junit.jupiter.api.Test;

import java.lang.reflect.Constructor;
import java.util.Arrays;
import java.util.Locale;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

class LastStoryOwnerCannotLeaveExceptionTest {

    private static final String SAFE_MESSAGE =
            "The last owner cannot leave the story";
    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000002");
    private static final String TOKEN = "access-token";

    @Test
    void shouldCreateExceptionWithSafeMessage() {

        LastStoryOwnerCannotLeaveException exception =
                new LastStoryOwnerCannotLeaveException();

        assertThat(exception)
                .hasMessage(SAFE_MESSAGE)
                .hasNoCause();
    }

    @Test
    void shouldUseStableSafeMessageAndToString() {

        LastStoryOwnerCannotLeaveException exception =
                new LastStoryOwnerCannotLeaveException();

        assertThat(exception.getMessage()).isEqualTo(SAFE_MESSAGE);
        assertThat(exception.toString())
                .isEqualTo(
                        LastStoryOwnerCannotLeaveException.class.getName()
                                + ": "
                                + SAFE_MESSAGE
                );
    }

    @Test
    void shouldNotExposeIdentifiersCountsAuthOrInfrastructureDetails() {

        LastStoryOwnerCannotLeaveException exception =
                new LastStoryOwnerCannotLeaveException();

        assertSafeText(exception.getMessage());
        assertSafeText(exception.toString());
    }

    @Test
    void shouldExposeOnlySafeNoArgumentConstructor() {

        assertThat(Arrays.stream(LastStoryOwnerCannotLeaveException.class
                .getConstructors())
                .map(Constructor::getParameterCount))
                .containsExactly(0);
    }

    private static void assertSafeText(String text) {
        assertThat(text)
                .doesNotContain(STORY_ID.toString())
                .doesNotContain(USER_ID.toString())
                .doesNotContain(TOKEN)
                .doesNotContain("1")
                .doesNotContain("0");

        assertThat(text.toLowerCase(Locale.ROOT))
                .doesNotContain("user")
                .doesNotContain("userid")
                .doesNotContain("storyid")
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
