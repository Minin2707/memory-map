package memory_map.backend.story.application;

import memory_map.backend.media.application.TransactionCommitCoordinator;
import memory_map.backend.media.application.TransactionRollbackCoordinator;
import memory_map.backend.media.image.ImageProcessor;
import memory_map.backend.media.storage.StorageService;
import memory_map.backend.story.repository.StoryRepository;
import memory_map.backend.story.repository.StoryParticipantViewRepository;
import memory_map.backend.story.repository.UserStoryRepository;
import memory_map.backend.storyparticipant.repository.StoryParticipantRepository;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
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
    @ConditionalOnProperty(
            prefix = "app.storage.minio",
            name = "enabled",
            havingValue = "true"
    )
    public DownloadStoryCoverUseCase downloadStoryCoverUseCase(
            StoryRepository storyRepository,
            StoryParticipantRepository storyParticipantRepository,
            StorageService storageService
    ) {
        return new DefaultDownloadStoryCoverService(
                storyRepository,
                storyParticipantRepository,
                storageService,
                new StoryAccessPolicy()
        );
    }

    @Bean
    @ConditionalOnProperty(
            prefix = "app.storage.minio",
            name = "enabled",
            havingValue = "true"
    )
    public StoryCoverStorageKeyFactory storyCoverStorageKeyFactory() {
        return new DeterministicStoryCoverStorageKeyFactory();
    }

    @Bean
    @ConditionalOnProperty(
            prefix = "app.storage.minio",
            name = "enabled",
            havingValue = "true"
    )
    public UploadStoryCoverUseCase uploadStoryCoverUseCase(
            StoryRepository storyRepository,
            StoryParticipantRepository storyParticipantRepository,
            UserStoryRepository userStoryRepository,
            ImageProcessor imageProcessor,
            StoryCoverStorageKeyFactory storageKeyFactory,
            StorageService storageService,
            TransactionRollbackCoordinator rollbackCoordinator,
            TransactionCommitCoordinator commitCoordinator
    ) {
        return new DefaultUploadStoryCoverService(
                storyRepository,
                storyParticipantRepository,
                userStoryRepository,
                imageProcessor,
                storageKeyFactory,
                storageService,
                rollbackCoordinator,
                commitCoordinator
        );
    }

    @Bean
    @ConditionalOnProperty(
            prefix = "app.storage.minio",
            name = "enabled",
            havingValue = "true"
    )
    public RemoveStoryCoverUseCase removeStoryCoverUseCase(
            StoryRepository storyRepository,
            StoryParticipantRepository storyParticipantRepository,
            UserStoryRepository userStoryRepository,
            StorageService storageService,
            TransactionCommitCoordinator commitCoordinator
    ) {
        return new DefaultRemoveStoryCoverService(
                storyRepository,
                storyParticipantRepository,
                userStoryRepository,
                storageService,
                commitCoordinator
        );
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
