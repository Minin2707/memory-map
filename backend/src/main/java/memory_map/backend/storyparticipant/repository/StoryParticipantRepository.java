package memory_map.backend.storyparticipant.repository;

import memory_map.backend.storyparticipant.domain.StoryParticipant;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface StoryParticipantRepository {

    Optional<StoryParticipant> find(UUID storyId, UUID userId);

    List<StoryParticipant> findByStoryId(UUID storyId);

    List<StoryParticipant> findByUserId(UUID userId);

    boolean exists(UUID storyId, UUID userId);

    void save(StoryParticipant participant);

    void update(StoryParticipant participant);

    void delete(UUID storyId, UUID userId);

}