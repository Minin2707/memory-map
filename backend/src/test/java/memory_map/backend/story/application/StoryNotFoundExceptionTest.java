package memory_map.backend.story.application;

import org.junit.jupiter.api.Test;

import java.util.Locale;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

class StoryNotFoundExceptionTest {

    private static final String SAFE_MESSAGE = "Story was not found";
    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000002");

    @Test
    void shouldCreateExceptionWithSafeMessage() {

        StoryNotFoundException exception = new StoryNotFoundException();

        assertThat(exception)
                .hasMessage(SAFE_MESSAGE)
                .hasNoCause();
    }

    @Test
    void shouldUseStableSafeMessageAndToString() {

        StoryNotFoundException exception = new StoryNotFoundException();

        assertThat(exception.getMessage()).isEqualTo(SAFE_MESSAGE);
        assertThat(exception.toString())
                .isEqualTo(
                        StoryNotFoundException.class.getName()
                                + ": "
                                + SAFE_MESSAGE
                );
    }

    @Test
    void shouldNotExposeIdentifiersOrInfrastructureDetails() {

        StoryNotFoundException exception = new StoryNotFoundException();

        assertSafeText(exception.getMessage());
        assertSafeText(exception.toString());
    }

    private static void assertSafeText(String text) {
        assertThat(text)
                .doesNotContain(STORY_ID.toString())
                .doesNotContain(USER_ID.toString());

        assertThat(text.toLowerCase(Locale.ROOT))
                .doesNotContain("user")
                .doesNotContain("sql")
                .doesNotContain("jdbc")
                .doesNotContain("repository")
                .doesNotContain("forbidden")
                .doesNotContain("access denied")
                .doesNotContain("inaccessible");
    }
}
