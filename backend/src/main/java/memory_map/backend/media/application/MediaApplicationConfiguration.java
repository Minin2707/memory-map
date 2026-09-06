package memory_map.backend.media.application;

import memory_map.backend.media.image.ImageProcessor;
import memory_map.backend.media.repository.AuthorizedMediaDownloadRepository;
import memory_map.backend.media.repository.MediaFileRepository;
import memory_map.backend.media.repository.StorageCleanupTaskRepository;
import memory_map.backend.media.storage.DeterministicMediaStorageKeyFactory;
import memory_map.backend.media.storage.MediaStorageKeyFactory;
import memory_map.backend.media.storage.StorageService;
import memory_map.backend.memory.repository.MemoryRepository;
import memory_map.backend.notification.application.NotificationPublisher;
import memory_map.backend.story.repository.StoryRepository;
import memory_map.backend.storyparticipant.repository.StoryParticipantRepository;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.time.Clock;

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
    public StorageCleanupScheduler storageCleanupScheduler(
            StorageCleanupTaskRepository storageCleanupTaskRepository,
            Clock clock
    ) {
        return new TransactionalStorageCleanupScheduler(
                storageCleanupTaskRepository,
                clock
        );
    }

    @Bean
    public StorageCleanupRecoveryScheduler storageCleanupRecoveryScheduler(
            StorageCleanupTaskRepository storageCleanupTaskRepository,
            Clock clock
    ) {
        return new TransactionalStorageCleanupRecoveryScheduler(
                storageCleanupTaskRepository,
                clock
        );
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
            AuthorizedMediaDownloadRepository
                    authorizedMediaDownloadRepository,
            StorageService storageService
    ) {
        return new TransactionalDownloadMediaService(
                authorizedMediaDownloadRepository,
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
            StoryRepository storyRepository,
            MemoryRepository memoryRepository,
            StoryParticipantRepository storyParticipantRepository,
            MediaFileRepository mediaFileRepository,
            PhotoUploadAuthorizationPolicy authorizationPolicy,
            ImageProcessor imageProcessor,
            MediaStorageKeyFactory storageKeyFactory,
            StorageService storageService,
            TransactionRollbackCoordinator rollbackCoordinator,
            StorageCleanupRecoveryScheduler recoveryScheduler,
            NotificationPublisher notificationPublisher
    ) {
        return new CoordinatedUploadPhotoService(
                storyRepository,
                memoryRepository,
                storyParticipantRepository,
                mediaFileRepository,
                authorizationPolicy,
                imageProcessor,
                storageKeyFactory,
                storageService,
                rollbackCoordinator,
                recoveryScheduler,
                notificationPublisher
        );
    }

    @Bean
    @ConditionalOnProperty(
            prefix = "app.storage.minio",
            name = "enabled",
            havingValue = "true"
    )
    public DeleteMediaUseCase deleteMediaUseCase(
            StoryRepository storyRepository,
            MediaFileRepository mediaFileRepository,
            MemoryRepository memoryRepository,
            StoryParticipantRepository storyParticipantRepository,
            DeleteMediaAuthorizationPolicy authorizationPolicy,
            StorageCleanupScheduler cleanupScheduler
    ) {
        return new TransactionalDeleteMediaService(
                storyRepository,
                mediaFileRepository,
                memoryRepository,
                storyParticipantRepository,
                authorizationPolicy,
                cleanupScheduler
        );
    }

    @Bean
    @ConditionalOnProperty(
            prefix = "app.storage.minio",
            name = "enabled",
            havingValue = "true"
    )
    public StorageCleanupProcessor storageCleanupProcessor(
            StorageCleanupTaskRepository storageCleanupTaskRepository,
            StorageService storageService,
            Clock clock
    ) {
        return new TransactionalStorageCleanupProcessor(
                storageCleanupTaskRepository,
                storageService,
                clock
        );
    }
}
