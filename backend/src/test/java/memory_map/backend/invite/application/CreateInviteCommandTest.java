package memory_map.backend.invite.application;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.storyparticipant.domain.StoryRole;
import org.junit.jupiter.api.Test;

import java.lang.reflect.RecordComponent;
import java.time.Instant;
import java.util.Arrays;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class CreateInviteCommandTest {

    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final AuthenticatedUser AUTHENTICATED_USER =
            new AuthenticatedUser(USER_ID);
    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000002");
    private static final UUID INVITE_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000003");
    private static final Instant CURRENT_TIME =
            Instant.parse("2026-01-01T10:00:00Z");

    @Test
    void shouldCreateCommandWhenRequiredFieldsAreValid() {

        CreateInviteCommand command = new CreateInviteCommand(
                AUTHENTICATED_USER,
                STORY_ID,
                INVITE_ID,
                StoryRole.CO_OWNER,
                CURRENT_TIME
        );

        assertThat(command.authenticatedUser())
                .isEqualTo(AUTHENTICATED_USER);
        assertThat(command.storyId()).isEqualTo(STORY_ID);
        assertThat(command.inviteId()).isEqualTo(INVITE_ID);
        assertThat(command.targetRole()).isEqualTo(StoryRole.CO_OWNER);
        assertThat(command.currentTime()).isEqualTo(CURRENT_TIME);
    }

    @Test
    void shouldRejectNullAuthenticatedUser() {

        assertThatThrownBy(() -> new CreateInviteCommand(
                null,
                STORY_ID,
                INVITE_ID,
                StoryRole.CO_OWNER,
                CURRENT_TIME
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("authenticatedUser must not be null");
    }

    @Test
    void shouldRejectNullStoryId() {

        assertThatThrownBy(() -> new CreateInviteCommand(
                AUTHENTICATED_USER,
                null,
                INVITE_ID,
                StoryRole.CO_OWNER,
                CURRENT_TIME
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("storyId must not be null");
    }

    @Test
    void shouldRejectNullInviteId() {

        assertThatThrownBy(() -> new CreateInviteCommand(
                AUTHENTICATED_USER,
                STORY_ID,
                null,
                StoryRole.CO_OWNER,
                CURRENT_TIME
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("inviteId must not be null");
    }

    @Test
    void shouldRejectNullTargetRole() {

        assertThatThrownBy(() -> new CreateInviteCommand(
                AUTHENTICATED_USER,
                STORY_ID,
                INVITE_ID,
                null,
                CURRENT_TIME
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("targetRole must not be null");
    }

    @Test
    void shouldRejectOwnerTargetRole() {

        assertThatThrownBy(() -> new CreateInviteCommand(
                AUTHENTICATED_USER,
                STORY_ID,
                INVITE_ID,
                StoryRole.OWNER,
                CURRENT_TIME
        ))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("targetRole must not be OWNER");
    }

    @Test
    void shouldRejectNullCurrentTime() {

        assertThatThrownBy(() -> new CreateInviteCommand(
                AUTHENTICATED_USER,
                STORY_ID,
                INVITE_ID,
                StoryRole.CO_OWNER,
                null
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("currentTime must not be null");
    }

    @Test
    void shouldPreserveValueSemantics() {

        CreateInviteCommand first = new CreateInviteCommand(
                AUTHENTICATED_USER,
                STORY_ID,
                INVITE_ID,
                StoryRole.CO_OWNER,
                CURRENT_TIME
        );
        CreateInviteCommand second = new CreateInviteCommand(
                AUTHENTICATED_USER,
                STORY_ID,
                INVITE_ID,
                StoryRole.CO_OWNER,
                CURRENT_TIME
        );
        CreateInviteCommand different = new CreateInviteCommand(
                AUTHENTICATED_USER,
                STORY_ID,
                UUID.fromString("00000000-0000-0000-0000-000000000004"),
                StoryRole.CO_OWNER,
                CURRENT_TIME
        );

        assertThat(first).isEqualTo(second);
        assertThat(first).isNotEqualTo(different);
        assertThat(first.hashCode()).isEqualTo(second.hashCode());
    }

    @Test
    void shouldUseSafeToString() {

        CreateInviteCommand command = new CreateInviteCommand(
                AUTHENTICATED_USER,
                STORY_ID,
                INVITE_ID,
                StoryRole.EDITOR,
                CURRENT_TIME
        );

        assertThat(command.toString())
                .contains("authenticatedUser=<redacted>")
                .contains("storyId=<redacted>")
                .contains("inviteId=<redacted>")
                .contains("targetRole=<redacted>")
                .contains(CURRENT_TIME.toString())
                .doesNotContain(USER_ID.toString())
                .doesNotContain(STORY_ID.toString())
                .doesNotContain(INVITE_ID.toString())
                .doesNotContain(StoryRole.EDITOR.name());
    }

    @Test
    void shouldContainOnlyBoundaryFields() {

        assertThat(recordComponentNames())
                .containsExactly(
                        "authenticatedUser",
                        "storyId",
                        "inviteId",
                        "targetRole",
                        "currentTime"
                );
    }

    @Test
    void shouldNotContainTokenLinkTtlOrPersistenceFields() {

        assertThat(recordComponentNames())
                .doesNotContain(
                        "rawToken",
                        "tokenHash",
                        "inviteLink",
                        "expiresAt",
                        "ttl",
                        "baseUrl",
                        "ownerId",
                        "createdBy"
                );
    }

    private static String[] recordComponentNames() {
        return Arrays.stream(CreateInviteCommand.class.getRecordComponents())
                .map(RecordComponent::getName)
                .toArray(String[]::new);
    }
}
