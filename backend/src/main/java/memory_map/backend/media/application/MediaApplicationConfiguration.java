package memory_map.backend.media.application;

import memory_map.backend.media.image.ImageProcessor;
import memory_map.backend.media.repository.MediaFileRepository;
import memory_map.backend.media.storage.DeterministicMediaStorageKeyFactory;
import memory_map.backend.media.storage.MediaStorageKeyFactory;
import memory_map.backend.media.storage.StorageService;
import memory_map.backend.memory.repository.MemoryRepository;
import memory_map.backend.storyparticipant.repository.StoryParticipantRepository;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class MediaApplicationConfiguration {

    @Bean
    public PhotoUploadAuthorizationPolicy photoUploadAuthorizationPolicy() {
        return new PhotoUploadAuthorizationPolicy();
    }

    @Bean
    public DeleteMediaAuthorizationPolicy deleteMediaAuthorizationPolicy() {
        return new DeleteMediaAuthorizationPolicy();
    }

    @Bean
    public MediaStorageKeyFactory mediaStorageKeyFactory() {
        return new DeterministicMediaStorageKeyFactory();
    }

    @Bean
    public TransactionRollbackCoordinator transactionRollbackCoordinator() {
        return new SpringTransactionRollbackCoordinator();
    }

    @Bean
    public TransactionCommitCoordinator transactionCommitCoordinator() {
        return new SpringTransactionCommitCoordinator();
    }

    @Bean
    public ListMemoryMediaUseCase listMemoryMediaUseCase(
            MemoryRepository memoryRepository,
            StoryParticipantRepository storyParticipantRepository,
            MediaFileRepository mediaFileRepository
    ) {
        return new TransactionalListMemoryMediaService(
                memoryRepository,
                storyParticipantRepository,
                mediaFileRepository
        );
    }

    @Bean
    @ConditionalOnProperty(
            prefix = "app.storage.minio",
            name = "enabled",
            havingValue = "true"
    )
    public DownloadMediaUseCase downloadMediaUseCase(
            MediaFileRepository mediaFileRepository,
            MemoryRepository memoryRepository,
            StoryParticipantRepository storyParticipantRepository,
            StorageService storageService
    ) {
        return new TransactionalDownloadMediaService(
                mediaFileRepository,
                memoryRepository,
                storyParticipantRepository,
                storageService
        );
    }

    @Bean
    @ConditionalOnProperty(
            prefix = "app.storage.minio",
            name = "enabled",
            havingValue = "true"
    )
    public UploadPhotoUseCase uploadPhotoUseCase(
            MemoryRepository memoryRepository,
            StoryParticipantRepository storyParticipantRepository,
            MediaFileRepository mediaFileRepository,
            PhotoUploadAuthorizationPolicy authorizationPolicy,
            ImageProcessor imageProcessor,
            MediaStorageKeyFactory storageKeyFactory,
            StorageService storageService,
            TransactionRollbackCoordinator rollbackCoordinator
    ) {
        return new CoordinatedUploadPhotoService(
                memoryRepository,
                storyParticipantRepository,
                mediaFileRepository,
                authorizationPolicy,
                imageProcessor,
                storageKeyFactory,
                storageService,
                rollbackCoordinator
        );
    }

    @Bean
    @ConditionalOnProperty(
            prefix = "app.storage.minio",
            name = "enabled",
            havingValue = "true"
    )
    public DeleteMediaUseCase deleteMediaUseCase(
            MediaFileRepository mediaFileRepository,
            MemoryRepository memoryRepository,
            StoryParticipantRepository storyParticipantRepository,
            DeleteMediaAuthorizationPolicy authorizationPolicy,
            StorageService storageService,
            TransactionCommitCoordinator commitCoordinator
    ) {
        return new TransactionalDeleteMediaService(
                mediaFileRepository,
                memoryRepository,
                storyParticipantRepository,
                authorizationPolicy,
                storageService,
                commitCoordinator
        );
    }
}
