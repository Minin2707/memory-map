package memory_map.backend.memory.application;

import memory_map.backend.memory.repository.MemoryRepository;
import memory_map.backend.memory.repository.MemoryReadRepository;
import memory_map.backend.storyparticipant.repository.StoryParticipantRepository;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class MemoryApplicationConfiguration {

    @Bean
    public CreateMemoryUseCase createMemoryUseCase(
            StoryParticipantRepository storyParticipantRepository,
            MemoryRepository memoryRepository
    ) {
        return new TransactionalCreateMemoryService(
                storyParticipantRepository,
                memoryRepository
        );
    }

    @Bean
    public GetStoryMemoriesUseCase getStoryMemoriesUseCase(
            MemoryReadRepository memoryReadRepository
    ) {
        return new DefaultGetStoryMemoriesService(memoryReadRepository);
    }

    @Bean
    public GetMemoryUseCase getMemoryUseCase(
            MemoryReadRepository memoryReadRepository
    ) {
        return new DefaultGetMemoryService(memoryReadRepository);
    }

    @Bean
    public UpdateMemoryUseCase updateMemoryUseCase(
            MemoryRepository memoryRepository,
            StoryParticipantRepository storyParticipantRepository
    ) {
        return new TransactionalUpdateMemoryService(
                memoryRepository,
                storyParticipantRepository
        );
    }

    @Bean
    public DeleteMemoryUseCase deleteMemoryUseCase(
            MemoryRepository memoryRepository,
            StoryParticipantRepository storyParticipantRepository
    ) {
        return new TransactionalDeleteMemoryService(
                memoryRepository,
                storyParticipantRepository
        );
    }
}
