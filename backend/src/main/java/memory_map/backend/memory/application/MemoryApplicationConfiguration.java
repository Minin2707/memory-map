package memory_map.backend.memory.application;

import memory_map.backend.media.application.TransactionCommitCoordinator;
import memory_map.backend.media.repository.MediaFileRepository;
import memory_map.backend.media.storage.StorageService;
import memory_map.backend.memory.repository.MemoryRepository;
import memory_map.backend.memory.repository.MemoryReadRepository;
import memory_map.backend.storyparticipant.repository.StoryParticipantRepository;
import org.springframework.beans.factory.ObjectProvider;
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
            StoryParticipantRepository storyParticipantRepository,
            MemoryMediaCleanupCoordinator mediaCleanupCoordinator
    ) {
        return new TransactionalDeleteMemoryService(
                memoryRepository,
                storyParticipantRepository,
                mediaCleanupCoordinator
        );
    }

    @Bean
    public MemoryMediaCleanupCoordinator memoryMediaCleanupCoordinator(
            MediaFileRepository mediaFileRepository,
            ObjectProvider<StorageService> storageServiceProvider,
            ObjectProvider<TransactionCommitCoordinator> commitCoordinatorProvider
    ) {
        StorageService storageService = storageServiceProvider.getIfAvailable();

        if (storageService == null) {
            return new StorageUnavailableMemoryMediaCleanupCoordinator(
                    mediaFileRepository
            );
        }

        return new StorageBackedMemoryMediaCleanupCoordinator(
                mediaFileRepository,
                storageService,
                commitCoordinatorProvider.getObject()
        );
    }
}
