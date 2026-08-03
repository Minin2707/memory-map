package memory_map.backend.invite.application;

import memory_map.backend.auth.domain.AuthenticatedUser;
import org.junit.jupiter.api.Test;

import java.lang.reflect.RecordComponent;
import java.time.Instant;
import java.util.Arrays;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class AcceptInviteCommandTest {

    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000002");
    private static final UUID INVITE_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000003");
    private static final AuthenticatedUser AUTHENTICATED_USER =
            new AuthenticatedUser(USER_ID);
    private static final String RAW_INVITE_TOKEN =
            "raw_INVITE-token_123";
    private static final Instant CURRENT_TIME =
            Instant.parse("2026-01-01T10:00:00Z");

    @Test
    void shouldCreateCommandWhenRequiredFieldsAreValid() {

        AcceptInviteCommand command = new AcceptInviteCommand(
                AUTHENTICATED_USER,
                RAW_INVITE_TOKEN,
                CURRENT_TIME
        );

        assertThat(command.authenticatedUser())
                .isEqualTo(AUTHENTICATED_USER);
        assertThat(command.rawInviteToken()).isEqualTo(RAW_INVITE_TOKEN);
        assertThat(command.currentTime()).isEqualTo(CURRENT_TIME);
    }

    @Test
    void shouldRejectNullAuthenticatedUser() {

        assertThatThrownBy(() -> new AcceptInviteCommand(
                null,
                RAW_INVITE_TOKEN,
                CURRENT_TIME
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("authenticatedUser must not be null");
    }

    @Test
    void shouldRejectNullRawInviteToken() {

        assertThatThrownBy(() -> new AcceptInviteCommand(
                AUTHENTICATED_USER,
                null,
                CURRENT_TIME
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("rawInviteToken must not be null");
    }

    @Test
    void shouldRejectBlankRawInviteToken() {

        assertThatThrownBy(() -> new AcceptInviteCommand(
                AUTHENTICATED_USER,
                "   ",
                CURRENT_TIME
        ))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("rawInviteToken must not be blank");
    }

    @Test
    void shouldRejectNullCurrentTime() {

        assertThatThrownBy(() -> new AcceptInviteCommand(
                AUTHENTICATED_USER,
                RAW_INVITE_TOKEN,
                null
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("currentTime must not be null");
    }

    @Test
    void shouldPreserveValueSemantics() {

        AcceptInviteCommand first = new AcceptInviteCommand(
                AUTHENTICATED_USER,
                RAW_INVITE_TOKEN,
                CURRENT_TIME
        );
        AcceptInviteCommand second = new AcceptInviteCommand(
                AUTHENTICATED_USER,
                RAW_INVITE_TOKEN,
                CURRENT_TIME
        );
        AcceptInviteCommand different = new AcceptInviteCommand(
                AUTHENTICATED_USER,
                "different_INVITE-token_123",
                CURRENT_TIME
        );

        assertThat(first).isEqualTo(second);
        assertThat(first).isNotEqualTo(different);
        assertThat(first.hashCode()).isEqualTo(second.hashCode());
    }

    @Test
    void shouldNotNormalizeRawInviteToken() {

        AcceptInviteCommand command = new AcceptInviteCommand(
                AUTHENTICATED_USER,
                "  raw_INVITE-token_123  ",
                CURRENT_TIME
        );

        assertThat(command.rawInviteToken())
                .isEqualTo("  raw_INVITE-token_123  ");
    }

    @Test
    void shouldUseSafeToString() {

        AcceptInviteCommand command = new AcceptInviteCommand(
                AUTHENTICATED_USER,
                RAW_INVITE_TOKEN,
                CURRENT_TIME
        );

        assertThat(command.toString())
                .contains("authenticatedUser=<redacted>")
                .contains("rawInviteToken=<redacted>")
                .contains(CURRENT_TIME.toString())
                .doesNotContain(RAW_INVITE_TOKEN)
                .doesNotContain(USER_ID.toString())
                .doesNotContain(STORY_ID.toString())
                .doesNotContain(INVITE_ID.toString());
    }

    @Test
    void shouldContainOnlyAcceptInviteBoundaryFields() {

        assertThat(recordComponentNames())
                .containsExactly(
                        "authenticatedUser",
                        "rawInviteToken",
                        "currentTime"
                );
    }

    @Test
    void shouldNotContainHashStoryInviteRoleOrExpirationFields() {

        assertThat(recordComponentNames())
                .doesNotContain(
                        "userId",
                        "storyId",
                        "inviteId",
                        "role",
                        "targetRole",
                        "expiresAt",
                        "usedAt",
                        "tokenHash",
                        "inviteLink",
                        "createdBy"
                );
    }

    private static String[] recordComponentNames() {
        return Arrays.stream(AcceptInviteCommand.class.getRecordComponents())
                .map(RecordComponent::getName)
                .toArray(String[]::new);
    }
}
