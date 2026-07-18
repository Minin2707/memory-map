package memory_map.backend.story.repository;

import memory_map.backend.story.domain.Story;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface StoryRepository {

    Story save(Story story);

    Optional<Story> findById(UUID id);

    List<Story> findByOwnerId(UUID ownerId);

}