package memory_map.backend.story.application;

import memory_map.backend.auth.domain.AuthenticatedUser;
import org.junit.jupiter.api.Test;

import java.lang.reflect.RecordComponent;
import java.util.Arrays;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class LeaveStoryCommandTest {

    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final AuthenticatedUser AUTHENTICATED_USER =
            new AuthenticatedUser(USER_ID);
    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000002");
    private static final UUID TARGET_USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000003");
    private static final UUID OWNER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000004");

    @Test
    void shouldCreateCommandWhenRequiredFieldsAreValid() {

        LeaveStoryCommand command = new LeaveStoryCommand(
                AUTHENTICATED_USER,
                STORY_ID
        );

        assertThat(command.authenticatedUser())
                .isEqualTo(AUTHENTICATED_USER);
        assertThat(command.storyId()).isEqualTo(STORY_ID);
    }

    @Test
    void shouldRejectNullAuthenticatedUser() {

        assertThatThrownBy(() -> new LeaveStoryCommand(
                null,
                STORY_ID
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("authenticatedUser must not be null");
    }

    @Test
    void shouldRejectNullStoryId() {

        assertThatThrownBy(() -> new LeaveStoryCommand(
                AUTHENTICATED_USER,
                null
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("storyId must not be null");
    }

    @Test
    void shouldPreserveValueSemantics() {

        LeaveStoryCommand first = new LeaveStoryCommand(
                AUTHENTICATED_USER,
                STORY_ID
        );
        LeaveStoryCommand second = new LeaveStoryCommand(
                AUTHENTICATED_USER,
                STORY_ID
        );
        LeaveStoryCommand different = new LeaveStoryCommand(
                AUTHENTICATED_USER,
                UUID.fromString("00000000-0000-0000-0000-000000000005")
        );

        assertThat(first).isEqualTo(second);
        assertThat(first).isNotEqualTo(different);
        assertThat(first.hashCode()).isEqualTo(second.hashCode());
    }

    @Test
    void shouldUseSafeToString() {

        LeaveStoryCommand command = new LeaveStoryCommand(
                AUTHENTICATED_USER,
                STORY_ID
        );

        assertThat(command.toString())
                .contains("authenticatedUser=<redacted>")
                .contains("storyId=<redacted>")
                .doesNotContain(USER_ID.toString())
                .doesNotContain(STORY_ID.toString());
    }

    @Test
    void shouldContainOnlyLeaveBoundaryFields() {

        assertThat(recordComponentNames())
                .containsExactly(
                        "authenticatedUser",
                        "storyId"
                );
    }

    @Test
    void shouldNotContainTargetRoleOwnerTimeOrTransferFields() {

        assertThat(recordComponentNames())
                .doesNotContain(
                        "userId",
                        "targetUserId",
                        "targetParticipantId",
                        "role",
                        "ownerId",
                        "currentTime",
                        "replacementOwnerId",
                        "transferTarget",
                        "reason"
                );
    }

    @Test
    void shouldNotNormalizeOrGenerateIdentifiers() {

        LeaveStoryCommand command = new LeaveStoryCommand(
                new AuthenticatedUser(USER_ID),
                STORY_ID
        );

        assertThat(command.authenticatedUser().userId()).isEqualTo(USER_ID);
        assertThat(command.storyId()).isEqualTo(STORY_ID);
        assertThat(command.toString())
                .doesNotContain(TARGET_USER_ID.toString())
                .doesNotContain(OWNER_ID.toString());
    }

    private static String[] recordComponentNames() {
        return Arrays.stream(LeaveStoryCommand.class.getRecordComponents())
                .map(RecordComponent::getName)
                .toArray(String[]::new);
    }
}
