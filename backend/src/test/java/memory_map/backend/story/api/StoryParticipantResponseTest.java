package memory_map.backend.story.api;

import memory_map.backend.story.application.StoryParticipantView;
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

class StoryParticipantResponseTest {

    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000002");
    private static final UUID OWNER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000003");
    private static final Instant JOINED_AT =
            Instant.parse("2026-01-01T10:00:00.123456Z");

    @Test
    void shouldMapFromParticipantView() {

        StoryParticipantResponse response =
                StoryParticipantResponse.from(participantView(
                        StoryRole.CO_OWNER,
                        "https://example.com/avatar.png"
                ));

        assertThat(response.userId()).isEqualTo(USER_ID);
        assertThat(response.displayName()).isEqualTo("Konstantin");
        assertThat(response.avatarUrl())
                .isEqualTo("https://example.com/avatar.png");
        assertThat(response.role()).isEqualTo(StoryRole.CO_OWNER);
        assertThat(response.joinedAt()).isEqualTo(JOINED_AT);
    }

    @ParameterizedTest
    @EnumSource(StoryRole.class)
    void shouldPreserveEveryRole(StoryRole role) {

        StoryParticipantResponse response =
                StoryParticipantResponse.from(participantView(role, null));

        assertThat(response.role()).isEqualTo(role);
    }

    @Test
    void shouldPreserveNullableAvatarUrl() {

        StoryParticipantResponse response =
                StoryParticipantResponse.from(participantView(
                        StoryRole.VIEWER,
                        null
                ));

        assertThat(response.avatarUrl()).isNull();
    }

    @Test
    void shouldRejectNullParticipantView() {

        assertThatThrownBy(() -> StoryParticipantResponse.from(null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("participant must not be null");
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

        StoryParticipantResponse response =
                StoryParticipantResponse.from(view);

        assertThat(response.displayName()).isEqualTo("  Konstantin  ");
        assertThat(response.avatarUrl())
                .isEqualTo(" https://example.com/avatar.png ");
    }

    @Test
    void shouldExposeExactRecordFields() {

        assertThat(Arrays.stream(StoryParticipantResponse.class
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
    void shouldExposeOnlyParticipantResponseFields() {

        StoryParticipantResponse response =
                StoryParticipantResponse.from(participantView(
                        StoryRole.OWNER,
                        "https://example.com/avatar.png"
                ));

        assertThat(response.toString())
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
