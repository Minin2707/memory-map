package memory_map.backend.story.application;

import memory_map.backend.auth.domain.AuthenticatedUser;
import org.junit.jupiter.api.Test;

import java.lang.reflect.RecordComponent;
import java.util.Arrays;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class RemoveStoryParticipantCommandTest {

    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final AuthenticatedUser AUTHENTICATED_USER =
            new AuthenticatedUser(USER_ID);
    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000002");
    private static final UUID PARTICIPANT_USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000003");
    private static final UUID OWNER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000004");

    @Test
    void shouldCreateCommandWhenRequiredFieldsAreValid() {

        RemoveStoryParticipantCommand command =
                new RemoveStoryParticipantCommand(
                        AUTHENTICATED_USER,
                        STORY_ID,
                        PARTICIPANT_USER_ID
                );

        assertThat(command.authenticatedUser())
                .isEqualTo(AUTHENTICATED_USER);
        assertThat(command.storyId()).isEqualTo(STORY_ID);
        assertThat(command.participantUserId())
                .isEqualTo(PARTICIPANT_USER_ID);
    }

    @Test
    void shouldRejectNullAuthenticatedUser() {

        assertThatThrownBy(() -> new RemoveStoryParticipantCommand(
                null,
                STORY_ID,
                PARTICIPANT_USER_ID
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("authenticatedUser must not be null");
    }

    @Test
    void shouldRejectNullStoryId() {

        assertThatThrownBy(() -> new RemoveStoryParticipantCommand(
                AUTHENTICATED_USER,
                null,
                PARTICIPANT_USER_ID
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("storyId must not be null");
    }

    @Test
    void shouldRejectNullParticipantUserId() {

        assertThatThrownBy(() -> new RemoveStoryParticipantCommand(
                AUTHENTICATED_USER,
                STORY_ID,
                null
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("participantUserId must not be null");
    }

    @Test
    void shouldAllowSelfTargetConstruction() {

        RemoveStoryParticipantCommand command =
                new RemoveStoryParticipantCommand(
                        AUTHENTICATED_USER,
                        STORY_ID,
                        USER_ID
                );

        assertThat(command.authenticatedUser().userId()).isEqualTo(USER_ID);
        assertThat(command.participantUserId()).isEqualTo(USER_ID);
    }

    @Test
    void shouldPreserveValueSemantics() {

        RemoveStoryParticipantCommand first =
                new RemoveStoryParticipantCommand(
                        AUTHENTICATED_USER,
                        STORY_ID,
                        PARTICIPANT_USER_ID
                );
        RemoveStoryParticipantCommand second =
                new RemoveStoryParticipantCommand(
                        AUTHENTICATED_USER,
                        STORY_ID,
                        PARTICIPANT_USER_ID
                );
        RemoveStoryParticipantCommand different =
                new RemoveStoryParticipantCommand(
                        AUTHENTICATED_USER,
                        STORY_ID,
                        UUID.fromString(
                                "00000000-0000-0000-0000-000000000005"
                        )
                );

        assertThat(first).isEqualTo(second);
        assertThat(first).isNotEqualTo(different);
        assertThat(first.hashCode()).isEqualTo(second.hashCode());
    }

    @Test
    void shouldUseSafeToString() {

        RemoveStoryParticipantCommand command =
                new RemoveStoryParticipantCommand(
                        AUTHENTICATED_USER,
                        STORY_ID,
                        PARTICIPANT_USER_ID
                );

        assertThat(command.toString())
                .contains("authenticatedUser=<redacted>")
                .contains("storyId=<redacted>")
                .contains("participantUserId=<redacted>")
                .doesNotContain(USER_ID.toString())
                .doesNotContain(STORY_ID.toString())
                .doesNotContain(PARTICIPANT_USER_ID.toString());
    }

    @Test
    void shouldContainOnlyRemoveParticipantBoundaryFields() {

        assertThat(recordComponentNames())
                .containsExactly(
                        "authenticatedUser",
                        "storyId",
                        "participantUserId"
                );
    }

    @Test
    void shouldNotContainRoleOwnerTimeTransferOrPermissionFields() {

        assertThat(recordComponentNames())
                .doesNotContain(
                        "actorUserId",
                        "userId",
                        "actorRole",
                        "targetRole",
                        "role",
                        "ownerId",
                        "currentTime",
                        "replacementOwner",
                        "replacementOwnerId",
                        "transferTarget",
                        "reason",
                        "permission",
                        "permissions"
                );
    }

    @Test
    void shouldNotNormalizeOrGenerateIdentifiers() {

        RemoveStoryParticipantCommand command =
                new RemoveStoryParticipantCommand(
                        new AuthenticatedUser(USER_ID),
                        STORY_ID,
                        PARTICIPANT_USER_ID
                );

        assertThat(command.authenticatedUser().userId()).isEqualTo(USER_ID);
        assertThat(command.storyId()).isEqualTo(STORY_ID);
        assertThat(command.participantUserId())
                .isEqualTo(PARTICIPANT_USER_ID);
        assertThat(command.toString()).doesNotContain(OWNER_ID.toString());
    }

    private static String[] recordComponentNames() {
        return Arrays.stream(
                RemoveStoryParticipantCommand.class.getRecordComponents()
        )
                .map(RecordComponent::getName)
                .toArray(String[]::new);
    }
}
