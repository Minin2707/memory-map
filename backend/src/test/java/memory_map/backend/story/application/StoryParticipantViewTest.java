package memory_map.backend.story.application;

import memory_map.backend.storyparticipant.domain.StoryRole;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;

import java.lang.reflect.RecordComponent;
import java.time.Instant;
import java.util.Arrays;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class StoryParticipantViewTest {

    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000002");
    private static final UUID OWNER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000003");
    private static final Instant JOINED_AT =
            Instant.parse("2026-01-01T10:00:00.123456Z");

    @Test
    void shouldCreateParticipantViewWhenRequiredFieldsAreValid() {

        StoryParticipantView view = participantView(
                StoryRole.CO_OWNER,
                "https://example.com/avatar.png"
        );

        assertThat(view.userId()).isEqualTo(USER_ID);
        assertThat(view.displayName()).isEqualTo("Konstantin");
        assertThat(view.avatarUrl())
                .isEqualTo("https://example.com/avatar.png");
        assertThat(view.role()).isEqualTo(StoryRole.CO_OWNER);
        assertThat(view.joinedAt()).isEqualTo(JOINED_AT);
    }

    @ParameterizedTest
    @EnumSource(StoryRole.class)
    void shouldAllowEveryStoryRole(StoryRole role) {

        StoryParticipantView view = participantView(role, null);

        assertThat(view.role()).isEqualTo(role);
    }

    @Test
    void shouldAllowNullableAvatarUrl() {

        StoryParticipantView view = participantView(StoryRole.VIEWER, null);

        assertThat(view.avatarUrl()).isNull();
    }

    @Test
    void shouldRejectNullUserId() {

        assertThatThrownBy(() -> new StoryParticipantView(
                null,
                "Konstantin",
                null,
                StoryRole.OWNER,
                JOINED_AT
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("userId must not be null");
    }

    @Test
    void shouldRejectNullDisplayName() {

        assertThatThrownBy(() -> new StoryParticipantView(
                USER_ID,
                null,
                null,
                StoryRole.OWNER,
                JOINED_AT
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("displayName must not be null");
    }

    @Test
    void shouldRejectBlankDisplayName() {

        assertThatThrownBy(() -> new StoryParticipantView(
                USER_ID,
                "",
                null,
                StoryRole.OWNER,
                JOINED_AT
        ))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("displayName must not be blank");

        assertThatThrownBy(() -> new StoryParticipantView(
                USER_ID,
                "   ",
                null,
                StoryRole.OWNER,
                JOINED_AT
        ))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("displayName must not be blank");
    }

    @Test
    void shouldRejectNullRole() {

        assertThatThrownBy(() -> new StoryParticipantView(
                USER_ID,
                "Konstantin",
                null,
                null,
                JOINED_AT
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("role must not be null");
    }

    @Test
    void shouldRejectNullJoinedAt() {

        assertThatThrownBy(() -> new StoryParticipantView(
                USER_ID,
                "Konstantin",
                null,
                StoryRole.OWNER,
                null
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("joinedAt must not be null");
    }

    @Test
    void shouldNotNormalizeValues() {

        StoryParticipantView view = new StoryParticipantView(
                USER_ID,
                "  Konstantin  ",
                " https://example.com/avatar.png ",
                StoryRole.EDITOR,
                JOINED_AT
        );

        assertThat(view.displayName()).isEqualTo("  Konstantin  ");
        assertThat(view.avatarUrl())
                .isEqualTo(" https://example.com/avatar.png ");
    }

    @Test
    void shouldPreserveValueSemantics() {

        StoryParticipantView first = participantView(StoryRole.OWNER, null);
        StoryParticipantView second = participantView(StoryRole.OWNER, null);
        StoryParticipantView different =
                participantView(StoryRole.EDITOR, null);

        assertThat(first).isEqualTo(second);
        assertThat(first).isNotEqualTo(different);
        assertThat(first.hashCode()).isEqualTo(second.hashCode());
    }

    @Test
    void shouldExposeExactRecordFields() {

        assertThat(Arrays.stream(StoryParticipantView.class
                .getRecordComponents())
                .map(RecordComponent::getName))
                .containsExactly(
                        "userId",
                        "displayName",
                        "avatarUrl",
                        "role",
                        "joinedAt"
                );
    }

    @Test
    void shouldExposeOnlyParticipantReadModelFields() {

        StoryParticipantView view = participantView(
                StoryRole.OWNER,
                "https://example.com/avatar.png"
        );

        assertThat(view.toString())
                .contains(USER_ID.toString())
                .contains("Konstantin")
                .contains("https://example.com/avatar.png")
                .contains(StoryRole.OWNER.name())
                .contains(JOINED_AT.toString())
                .doesNotContain("google-subject")
                .doesNotContain("email")
                .doesNotContain(STORY_ID.toString())
                .doesNotContain(OWNER_ID.toString())
                .doesNotContain("ownerId")
                .doesNotContain("storyId")
                .doesNotContain("permission")
                .doesNotContain("availableAction")
                .doesNotContain("isCurrentUser");
    }

    private static StoryParticipantView participantView(
            StoryRole role,
            String avatarUrl
    ) {
        return new StoryParticipantView(
                USER_ID,
                "Konstantin",
                avatarUrl,
                role,
                JOINED_AT
        );
    }
}
