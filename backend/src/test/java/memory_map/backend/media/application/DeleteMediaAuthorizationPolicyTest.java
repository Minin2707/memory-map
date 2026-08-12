package memory_map.backend.media.application;

import memory_map.backend.memory.domain.Memory;
import memory_map.backend.storyparticipant.domain.StoryParticipant;
import memory_map.backend.storyparticipant.domain.StoryRole;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class DeleteMediaAuthorizationPolicyTest {

    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID AUTHOR_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000002");
    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000011");
    private static final UUID OTHER_STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000012");
    private static final Instant BASE_TIME =
            Instant.parse("2026-01-01T10:00:00Z");

    private final DeleteMediaAuthorizationPolicy policy =
            new DeleteMediaAuthorizationPolicy();

    @Test
    void shouldAllowOwnerAndCoOwnerForAnyAuthorsMemory() {
        assertThat(policy.canDeleteMedia(
                participant(USER_ID, StoryRole.OWNER),
                memory(AUTHOR_ID),
                USER_ID
        )).isTrue();
        assertThat(policy.canDeleteMedia(
                participant(USER_ID, StoryRole.CO_OWNER),
                memory(AUTHOR_ID),
                USER_ID
        )).isTrue();
    }

    @Test
    void shouldAllowEditorAndViewerOnlyForOwnMemory() {
        assertThat(policy.canDeleteMedia(
                participant(USER_ID, StoryRole.EDITOR),
                memory(USER_ID),
                USER_ID
        )).isTrue();
        assertThat(policy.canDeleteMedia(
                participant(USER_ID, StoryRole.VIEWER),
                memory(USER_ID),
                USER_ID
        )).isTrue();
        assertThat(policy.canDeleteMedia(
                participant(USER_ID, StoryRole.EDITOR),
                memory(AUTHOR_ID),
                USER_ID
        )).isFalse();
        assertThat(policy.canDeleteMedia(
                participant(USER_ID, StoryRole.VIEWER),
                memory(AUTHOR_ID),
                USER_ID
        )).isFalse();
    }

    @Test
    void shouldRequireParticipantStoryAndRequesterUserToMatch() {
        assertThat(policy.canDeleteMedia(
                new StoryParticipant(
                        OTHER_STORY_ID,
                        USER_ID,
                        StoryRole.OWNER,
                        BASE_TIME
                ),
                memory(AUTHOR_ID),
                USER_ID
        )).isFalse();

        assertThat(policy.canDeleteMedia(
                participant(AUTHOR_ID, StoryRole.OWNER),
                memory(AUTHOR_ID),
                USER_ID
        )).isFalse();
    }

    @Test
    void shouldRejectNullArguments() {
        assertThatThrownBy(() -> policy.canDeleteMedia(
                null,
                memory(AUTHOR_ID),
                USER_ID
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("participant must not be null");
        assertThatThrownBy(() -> policy.canDeleteMedia(
                participant(USER_ID, StoryRole.OWNER),
                null,
                USER_ID
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("memory must not be null");
        assertThatThrownBy(() -> policy.canDeleteMedia(
                participant(USER_ID, StoryRole.OWNER),
                memory(AUTHOR_ID),
                null
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("requesterUserId must not be null");
    }

    private static StoryParticipant participant(UUID userId, StoryRole role) {
        return new StoryParticipant(STORY_ID, userId, role, BASE_TIME);
    }

    private static Memory memory(UUID createdBy) {
        return new Memory(
                UUID.fromString("00000000-0000-0000-0000-000000000021"),
                STORY_ID,
                createdBy,
                "First trip",
                "A spring walk",
                "Tbilisi",
                41.715137,
                44.827096,
                LocalDate.of(2024, 5, 20),
                BASE_TIME,
                BASE_TIME
        );
    }
}
