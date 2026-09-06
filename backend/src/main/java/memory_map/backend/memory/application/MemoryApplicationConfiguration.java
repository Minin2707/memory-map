package memory_map.backend.memory.application;

import memory_map.backend.media.application.StorageCleanupScheduler;
import memory_map.backend.media.repository.MediaFileRepository;
import memory_map.backend.media.storage.StorageService;
import memory_map.backend.memory.repository.MemoryRepository;
import memory_map.backend.memory.repository.MemoryReadRepository;
import memory_map.backend.notification.application.NotificationPublisher;
import memory_map.backend.story.repository.StoryRepository;
import memory_map.backend.storyparticipant.repository.StoryParticipantRepository;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class MemoryApplicationConfiguration {

    @Bean
    public CreateMemoryUseCase createMemoryUseCase(
            StoryRepository storyRepository,
            StoryParticipantRepository storyParticipantRepository,
            MemoryRepository memoryRepository,
            NotificationPublisher notificationPublisher
    ) {
        return new TransactionalCreateMemoryService(
                storyRepository,
                storyParticipantRepository,
                memoryRepository,
                notificationPublisher
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
            StoryRepository storyRepository,
            MemoryRepository memoryRepository,
            StoryParticipantRepository storyParticipantRepository
    ) {
        return new TransactionalUpdateMemoryService(
                storyRepository,
                memoryRepository,
                storyParticipantRepository
        );
    }

    @Bean
    public DeleteMemoryUseCase deleteMemoryUseCase(
            StoryRepository storyRepository,
            MemoryRepository memoryRepository,
            StoryParticipantRepository storyParticipantRepository,
            MemoryMediaCleanupCoordinator mediaCleanupCoordinator
    ) {
        return new TransactionalDeleteMemoryService(
                storyRepository,
                memoryRepository,
                storyParticipantRepository,
                mediaCleanupCoordinator
        );
    }

    @Bean
    public MemoryMediaCleanupCoordinator memoryMediaCleanupCoordinator(
            MediaFileRepository mediaFileRepository,
            ObjectProvider<StorageService> storageServiceProvider,
            ObjectProvider<StorageCleanupScheduler> cleanupSchedulerProvider
    ) {
        StorageService storageService = storageServiceProvider.getIfAvailable();

        if (storageService == null) {
            return new StorageUnavailableMemoryMediaCleanupCoordinator(
                    mediaFileRepository
            );
        }

        return new StorageBackedMemoryMediaCleanupCoordinator(
                mediaFileRepository,
                cleanupSchedulerProvider.getObject()
        );
    }
}
