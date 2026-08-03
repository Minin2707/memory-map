package memory_map.backend.invite.application;

import memory_map.backend.storyparticipant.domain.StoryRole;
import org.junit.jupiter.api.Test;

import java.util.Locale;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

class InviteAcceptanceUnavailableExceptionTest {

    private static final String SAFE_MESSAGE =
            "Invite could not be accepted";
    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000002");
    private static final String RAW_INVITE_TOKEN =
            "raw_INVITE-token_123";
    private static final String TOKEN_HASH =
            "sha256-token-hash";

    @Test
    void shouldCreateExceptionWithSafeMessage() {

        InviteAcceptanceUnavailableException exception =
                new InviteAcceptanceUnavailableException();

        assertThat(exception)
                .hasMessage(SAFE_MESSAGE)
                .hasNoCause();
    }

    @Test
    void shouldUseStableSafeMessageAndToString() {

        InviteAcceptanceUnavailableException exception =
                new InviteAcceptanceUnavailableException();

        assertThat(exception.getMessage()).isEqualTo(SAFE_MESSAGE);
        assertThat(exception.toString())
                .isEqualTo(
                        InviteAcceptanceUnavailableException.class.getName()
                                + ": "
                                + SAFE_MESSAGE
                );
    }

    @Test
    void shouldNotExposeTokenIdentifiersStateRolesOrInfrastructureDetails() {

        InviteAcceptanceUnavailableException exception =
                new InviteAcceptanceUnavailableException();

        assertSafeText(exception.getMessage());
        assertSafeText(exception.toString());
    }

    private static void assertSafeText(String text) {
        assertThat(text)
                .doesNotContain(STORY_ID.toString())
                .doesNotContain(USER_ID.toString())
                .doesNotContain(RAW_INVITE_TOKEN)
                .doesNotContain(TOKEN_HASH)
                .doesNotContain(StoryRole.OWNER.name())
                .doesNotContain(StoryRole.CO_OWNER.name())
                .doesNotContain(StoryRole.EDITOR.name())
                .doesNotContain(StoryRole.VIEWER.name());

        assertThat(text.toLowerCase(Locale.ROOT))
                .doesNotContain("token")
                .doesNotContain("story")
                .doesNotContain("user")
                .doesNotContain("hash")
                .doesNotContain("role")
                .doesNotContain("expired")
                .doesNotContain("used")
                .doesNotContain("repository")
                .doesNotContain("jdbc")
                .doesNotContain("sql")
                .doesNotContain("forbidden")
                .doesNotContain("access denied")
                .doesNotContain("inaccessible");
    }
}
