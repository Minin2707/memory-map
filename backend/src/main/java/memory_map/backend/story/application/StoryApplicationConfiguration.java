package memory_map.backend.story.application;

import memory_map.backend.story.repository.StoryRepository;
import memory_map.backend.storyparticipant.repository.StoryParticipantRepository;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class StoryApplicationConfiguration {

    @Bean
    public CreateStoryUseCase createStoryUseCase(
            StoryRepository storyRepository,
            StoryParticipantRepository storyParticipantRepository
    ) {
        return new TransactionalCreateStoryService(
                storyRepository,
                storyParticipantRepository
        );
    }
}
