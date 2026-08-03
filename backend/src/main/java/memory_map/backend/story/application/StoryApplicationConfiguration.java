package memory_map.backend.story.application;

import memory_map.backend.story.repository.StoryRepository;
import memory_map.backend.story.repository.StoryParticipantViewRepository;
import memory_map.backend.story.repository.UserStoryRepository;
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

    @Bean
    public GetStoriesUseCase getStoriesUseCase(
            UserStoryRepository userStoryRepository
    ) {
        return new DefaultGetStoriesService(userStoryRepository);
    }

    @Bean
    public GetStoryUseCase getStoryUseCase(
            UserStoryRepository userStoryRepository
    ) {
        return new DefaultGetStoryService(userStoryRepository);
    }

    @Bean
    public GetStoryParticipantsUseCase getStoryParticipantsUseCase(
            StoryParticipantViewRepository repository
    ) {
        return new DefaultGetStoryParticipantsService(repository);
    }

    @Bean
    public UpdateStoryUseCase updateStoryUseCase(
            UserStoryRepository userStoryRepository,
            StoryRepository storyRepository
    ) {
        return new TransactionalUpdateStoryService(
                userStoryRepository,
                storyRepository
        );
    }

    @Bean
    public LeaveStoryUseCase leaveStoryUseCase(
            StoryRepository storyRepository,
            StoryParticipantRepository storyParticipantRepository
    ) {
        return new TransactionalLeaveStoryService(
                storyRepository,
                storyParticipantRepository
        );
    }

    @Bean
    public RemoveStoryParticipantUseCase removeStoryParticipantUseCase(
            StoryRepository storyRepository,
            StoryParticipantRepository storyParticipantRepository
    ) {
        return new TransactionalRemoveStoryParticipantService(
                storyRepository,
                storyParticipantRepository
        );
    }
}
