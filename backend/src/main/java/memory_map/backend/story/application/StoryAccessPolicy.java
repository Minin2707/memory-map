package memory_map.backend.story.application;

import memory_map.backend.storyparticipant.domain.StoryRole;

import java.util.Objects;

public final class StoryAccessPolicy {

    public boolean canReadStory(StoryRole role) {
        Objects.requireNonNull(role, "role must not be null");

        return role == StoryRole.OWNER
                || role == StoryRole.CO_OWNER
                || role == StoryRole.EDITOR
                || role == StoryRole.VIEWER;
    }

    public boolean canChangeStorySoundtrack(StoryRole role) {
        Objects.requireNonNull(role, "role must not be null");

        return role == StoryRole.OWNER
                || role == StoryRole.CO_OWNER;
    }
}
