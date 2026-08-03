package memory_map.backend.story.repository;

import memory_map.backend.story.application.StoryParticipantView;

import java.util.List;
import java.util.UUID;

public interface StoryParticipantViewRepository {

    List<StoryParticipantView> findByStoryIdAndRequesterUserId(
            UUID storyId,
            UUID requesterUserId
    );

}
