package memory_map.backend.story.application;

import memory_map.backend.story.domain.Story;

public interface CreateStoryUseCase {

    Story create(CreateStoryCommand command);

}
