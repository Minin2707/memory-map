package memory_map.backend.story.application;

import memory_map.backend.storyparticipant.domain.StoryRole;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class StoryAccessPolicyTest {

    private final StoryAccessPolicy policy = new StoryAccessPolicy();

    @ParameterizedTest
    @EnumSource(StoryRole.class)
    void shouldAllowAllParticipantRolesToReadStory(StoryRole role) {
        assertThat(policy.canReadStory(role)).isTrue();
    }

    @ParameterizedTest
    @EnumSource(value = StoryRole.class, names = {"OWNER", "CO_OWNER"})
    void shouldAllowOwnerAndCoOwnerToChangeStorySoundtrack(StoryRole role) {
        assertThat(policy.canChangeStorySoundtrack(role)).isTrue();
    }

    @ParameterizedTest
    @EnumSource(value = StoryRole.class, names = {"EDITOR", "VIEWER"})
    void shouldDenyEditorAndViewerForStorySoundtrackChange(StoryRole role) {
        assertThat(policy.canChangeStorySoundtrack(role)).isFalse();
    }

    @Test
    void shouldRejectNullRole() {
        assertThatThrownBy(() -> policy.canReadStory(null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("role must not be null");

        assertThatThrownBy(() -> policy.canChangeStorySoundtrack(null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("role must not be null");
    }
}
