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

class PhotoUploadAuthorizationPolicyTest {

    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID OTHER_STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000002");
    private static final UUID MEMORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000003");
    private static final UUID AUTHOR_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000004");
    private static final UUID REQUESTER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000005");
    private static final Instant NOW =
            Instant.parse("2026-01-01T10:00:00Z");

    @Test
    void shouldAllowOwnerForAnyMemoryInCurrentStory() {
        assertThat(canUpload(StoryRole.OWNER, REQUESTER_ID, memory(AUTHOR_ID)))
                .isTrue();
    }

    @Test
    void shouldAllowCoOwnerForAnyMemoryInCurrentStory() {
        assertThat(canUpload(StoryRole.CO_OWNER, REQUESTER_ID, memory(AUTHOR_ID)))
                .isTrue();
    }

    @Test
    void shouldAllowEditorAuthor() {
        assertThat(canUpload(StoryRole.EDITOR, AUTHOR_ID, memory(AUTHOR_ID)))
                .isTrue();
    }

    @Test
    void shouldDenyEditorForAnotherAuthorsMemory() {
        assertThat(canUpload(StoryRole.EDITOR, REQUESTER_ID, memory(AUTHOR_ID)))
                .isFalse();
    }

    @Test
    void shouldDenyViewerAuthor() {
        assertThat(canUpload(StoryRole.VIEWER, AUTHOR_ID, memory(AUTHOR_ID)))
                .isFalse();
    }

    @Test
    void shouldDenyViewerForAnotherAuthorsMemory() {
        assertThat(canUpload(StoryRole.VIEWER, REQUESTER_ID, memory(AUTHOR_ID)))
                .isFalse();
    }

    @Test
    void shouldDenyParticipantOfAnotherStoryEvenWhenOwner() {
        StoryParticipant participant = participant(
                OTHER_STORY_ID,
                REQUESTER_ID,
                StoryRole.OWNER
        );

        assertThat(PhotoUploadAuthorizationPolicy.canUpload(
                participant,
                memory(AUTHOR_ID),
                REQUESTER_ID
        )).isFalse();
    }

    @Test
    void shouldDenyWrongMembershipUserEvenWhenAuthor() {
        StoryParticipant participant = participant(
                STORY_ID,
                REQUESTER_ID,
                StoryRole.VIEWER
        );

        assertThat(PhotoUploadAuthorizationPolicy.canUpload(
                participant,
                memory(AUTHOR_ID),
                AUTHOR_ID
        )).isFalse();
    }

    @Test
    void shouldDenyFormerAuthorWithoutCurrentMembership() {
        StoryParticipant oldDifferentUserMembership = participant(
                STORY_ID,
                REQUESTER_ID,
                StoryRole.OWNER
        );

        assertThat(PhotoUploadAuthorizationPolicy.canUpload(
                oldDifferentUserMembership,
                memory(AUTHOR_ID),
                AUTHOR_ID
        )).isFalse();
    }

    @Test
    void shouldRejectNullInputs() {
        StoryParticipant participant = participant(
                STORY_ID,
                REQUESTER_ID,
                StoryRole.OWNER
        );
        Memory memory = memory(AUTHOR_ID);

        assertThatThrownBy(() -> PhotoUploadAuthorizationPolicy.canUpload(
                null,
                memory,
                REQUESTER_ID
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("participant must not be null");

        assertThatThrownBy(() -> PhotoUploadAuthorizationPolicy.canUpload(
                participant,
                null,
                REQUESTER_ID
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("memory must not be null");

        assertThatThrownBy(() -> PhotoUploadAuthorizationPolicy.canUpload(
                participant,
                memory,
                null
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("requesterUserId must not be null");
    }

    private static boolean canUpload(
            StoryRole role,
            UUID requesterUserId,
            Memory memory
    ) {
        return PhotoUploadAuthorizationPolicy.canUpload(
                participant(STORY_ID, requesterUserId, role),
                memory,
                requesterUserId
        );
    }

    private static StoryParticipant participant(
            UUID storyId,
            UUID userId,
            StoryRole role
    ) {
        return new StoryParticipant(
                storyId,
                userId,
                role,
                NOW
        );
    }

    private static Memory memory(UUID createdBy) {
        return new Memory(
                MEMORY_ID,
                STORY_ID,
                createdBy,
                "First day in Tbilisi",
                "A quiet morning",
                "Tbilisi",
                41.715137,
                44.827096,
                LocalDate.of(2024, 5, 18),
                NOW,
                NOW
        );
    }
}
