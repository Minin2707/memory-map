package memory_map.backend.invite.api;

import memory_map.backend.storyparticipant.domain.StoryRole;

public enum InviteTargetRole {

    CO_OWNER,
    EDITOR,
    VIEWER;

    StoryRole toStoryRole() {
        return StoryRole.valueOf(name());
    }
}
