package memory_map.backend.invite.application;

import memory_map.backend.storyparticipant.domain.StoryRole;
import org.junit.jupiter.api.Test;

import java.util.Locale;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

class InviteCreationUnavailableExceptionTest {

    private static final String SAFE_MESSAGE =
            "Invite could not be created";
    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000002");

    @Test
    void shouldCreateExceptionWithSafeMessage() {

        InviteCreationUnavailableException exception =
                new InviteCreationUnavailableException();

        assertThat(exception)
                .hasMessage(SAFE_MESSAGE)
                .hasNoCause();
    }

    @Test
    void shouldUseStableSafeMessageAndToString() {

        InviteCreationUnavailableException exception =
                new InviteCreationUnavailableException();

        assertThat(exception.getMessage()).isEqualTo(SAFE_MESSAGE);
        assertThat(exception.toString())
                .isEqualTo(
                        InviteCreationUnavailableException.class.getName()
                                + ": "
                                + SAFE_MESSAGE
                );
    }

    @Test
    void shouldNotExposeIdentifiersAccessRolesOrInfrastructureDetails() {

        InviteCreationUnavailableException exception =
                new InviteCreationUnavailableException();

        assertSafeText(exception.getMessage());
        assertSafeText(exception.toString());
    }

    private static void assertSafeText(String text) {
        assertThat(text)
                .doesNotContain(STORY_ID.toString())
                .doesNotContain(USER_ID.toString())
                .doesNotContain(StoryRole.OWNER.name())
                .doesNotContain(StoryRole.CO_OWNER.name())
                .doesNotContain(StoryRole.EDITOR.name())
                .doesNotContain(StoryRole.VIEWER.name());

        assertThat(text.toLowerCase(Locale.ROOT))
                .doesNotContain("user")
                .doesNotContain("story")
                .doesNotContain("role")
                .doesNotContain("sql")
                .doesNotContain("jdbc")
                .doesNotContain("repository")
                .doesNotContain("forbidden")
                .doesNotContain("access denied")
                .doesNotContain("inaccessible")
                .doesNotContain("token")
                .doesNotContain("hash")
                .doesNotContain("link");
    }
}
