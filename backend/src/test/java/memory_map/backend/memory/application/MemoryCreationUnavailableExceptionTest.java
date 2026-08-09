package memory_map.backend.memory.application;

import memory_map.backend.storyparticipant.domain.StoryRole;
import org.junit.jupiter.api.Test;

import java.util.Locale;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

class MemoryCreationUnavailableExceptionTest {

    private static final String SAFE_MESSAGE =
            "Memory could not be created";
    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000002");
    private static final UUID MEMORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000003");

    @Test
    void shouldCreateExceptionWithSafeMessage() {

        MemoryCreationUnavailableException exception =
                new MemoryCreationUnavailableException();

        assertThat(exception)
                .hasMessage(SAFE_MESSAGE)
                .hasNoCause();
    }

    @Test
    void shouldUseStableSafeMessageAndToString() {

        MemoryCreationUnavailableException exception =
                new MemoryCreationUnavailableException();

        assertThat(exception.getMessage()).isEqualTo(SAFE_MESSAGE);
        assertThat(exception.toString())
                .isEqualTo(
                        MemoryCreationUnavailableException.class.getName()
                                + ": "
                                + SAFE_MESSAGE
                );
    }

    @Test
    void shouldNotExposeIdentifiersLocationAccessRolesOrInfrastructureDetails() {

        MemoryCreationUnavailableException exception =
                new MemoryCreationUnavailableException();

        assertSafeText(exception.getMessage());
        assertSafeText(exception.toString());
    }

    private static void assertSafeText(String text) {
        assertThat(text)
                .doesNotContain(STORY_ID.toString())
                .doesNotContain(USER_ID.toString())
                .doesNotContain(MEMORY_ID.toString())
                .doesNotContain("41.715137")
                .doesNotContain("44.827096")
                .doesNotContain("A spring walk")
                .doesNotContain("Tbilisi")
                .doesNotContain(StoryRole.OWNER.name())
                .doesNotContain(StoryRole.CO_OWNER.name())
                .doesNotContain(StoryRole.EDITOR.name())
                .doesNotContain(StoryRole.VIEWER.name());

        assertThat(text.toLowerCase(Locale.ROOT))
                .doesNotContain("user")
                .doesNotContain("story")
                .doesNotContain("role")
                .doesNotContain("owner")
                .doesNotContain("viewer")
                .doesNotContain("participant")
                .doesNotContain("coordinate")
                .doesNotContain("latitude")
                .doesNotContain("longitude")
                .doesNotContain("sql")
                .doesNotContain("jdbc")
                .doesNotContain("repository")
                .doesNotContain("forbidden")
                .doesNotContain("access denied")
                .doesNotContain("inaccessible")
                .doesNotContain("not found");
    }
}
