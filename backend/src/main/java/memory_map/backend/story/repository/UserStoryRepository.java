package memory_map.backend.story.repository;

import memory_map.backend.story.application.UserStory;

import java.util.List;
import java.util.UUID;

public interface UserStoryRepository {

    List<UserStory> findByUserId(UUID userId);

}
