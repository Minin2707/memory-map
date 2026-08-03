package memory_map.backend.story.application;

import org.junit.jupiter.api.Test;

import java.lang.reflect.Constructor;
import java.util.Arrays;
import java.util.Locale;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

class ParticipantCannotRemoveSelfExceptionTest {

    private static final String SAFE_MESSAGE =
            "Use the leave story operation to remove yourself";
    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000002");

    @Test
    void shouldCreateExceptionWithSafeMessage() {

        ParticipantCannotRemoveSelfException exception =
                new ParticipantCannotRemoveSelfException();

        assertThat(exception)
                .hasMessage(SAFE_MESSAGE)
                .hasNoCause();
    }

    @Test
    void shouldUseStableSafeMessageAndToString() {

        ParticipantCannotRemoveSelfException exception =
                new ParticipantCannotRemoveSelfException();

        assertThat(exception.getMessage()).isEqualTo(SAFE_MESSAGE);
        assertThat(exception.toString())
                .isEqualTo(
                        ParticipantCannotRemoveSelfException.class.getName()
                                + ": "
                                + SAFE_MESSAGE
                );
    }

    @Test
    void shouldNotExposeIdentifiersRolesOrInfrastructureDetails() {

        ParticipantCannotRemoveSelfException exception =
                new ParticipantCannotRemoveSelfException();

        assertSafeText(exception.getMessage());
        assertSafeText(exception.toString());
    }

    @Test
    void shouldExposeOnlySafeNoArgumentConstructor() {

        assertThat(Arrays.stream(ParticipantCannotRemoveSelfException.class
                .getConstructors())
                .map(Constructor::getParameterCount))
                .containsExactly(0);
    }

    private static void assertSafeText(String text) {
        assertThat(text)
                .doesNotContain(STORY_ID.toString())
                .doesNotContain(USER_ID.toString())
                .doesNotContain("OWNER")
                .doesNotContain("CO_OWNER")
                .doesNotContain("EDITOR")
                .doesNotContain("VIEWER");

        assertThat(text.toLowerCase(Locale.ROOT))
                .doesNotContain("userid")
                .doesNotContain("storyid")
                .doesNotContain("actor")
                .doesNotContain("target")
                .doesNotContain("sql")
                .doesNotContain("jdbc")
                .doesNotContain("repository")
                .doesNotContain("http")
                .doesNotContain("status")
                .doesNotContain("token")
                .doesNotContain("auth");
    }
}
