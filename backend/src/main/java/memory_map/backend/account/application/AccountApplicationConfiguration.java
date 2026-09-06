package memory_map.backend.account.application;

import memory_map.backend.account.repository.AccountDeletionRepository;
import memory_map.backend.auth.repository.RefreshTokenRepository;
import memory_map.backend.media.application.StorageCleanupRecoveryScheduler;
import memory_map.backend.media.application.StorageCleanupScheduler;
import memory_map.backend.media.application.TransactionRollbackCoordinator;
import memory_map.backend.media.image.ImageProcessor;
import memory_map.backend.media.storage.StorageService;
import memory_map.backend.user.repository.UserRepository;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class AccountApplicationConfiguration {

    @Bean
    public DeleteCurrentAccountUseCase deleteCurrentAccountUseCase(
            UserRepository userRepository,
            AccountDeletionRepository accountDeletionRepository,
            RefreshTokenRepository refreshTokenRepository,
            AccountDeletionMediaCleanupCoordinator mediaCleanupCoordinator
    ) {
        return new TransactionalDeleteCurrentAccountService(
                userRepository,
                accountDeletionRepository,
                refreshTokenRepository,
                mediaCleanupCoordinator
        );
    }

    @Bean
    public UpdateCurrentUserDisplayNameUseCase
    updateCurrentUserDisplayNameUseCase(
            UserRepository userRepository
    ) {
        return new TransactionalCurrentUserProfileService(userRepository);
    }

    @Bean
    public AccountDeletionMediaCleanupCoordinator
    accountDeletionMediaCleanupCoordinator(
            ObjectProvider<StorageService> storageServiceProvider,
            ObjectProvider<StorageCleanupScheduler> cleanupSchedulerProvider
    ) {
        StorageService storageService = storageServiceProvider.getIfAvailable();

        if (storageService == null) {
            return new NoOpAccountDeletionMediaCleanupCoordinator();
        }

        return new StorageBackedAccountDeletionMediaCleanupCoordinator(
                cleanupSchedulerProvider.getObject()
        );
    }

    @Bean
    @ConditionalOnProperty(
            prefix = "app.storage.minio",
            name = "enabled",
            havingValue = "true"
    )
    public UserAvatarStorageKeyFactory userAvatarStorageKeyFactory() {
        return new DeterministicUserAvatarStorageKeyFactory();
    }

    @Bean
    @ConditionalOnProperty(
            prefix = "app.storage.minio",
            name = "enabled",
            havingValue = "true"
    )
    public UserAvatarImageProcessor userAvatarImageProcessor(
            ImageProcessor imageProcessor
    ) {
        return new UserAvatarImageProcessor(imageProcessor);
    }

    @Bean
    @ConditionalOnProperty(
            prefix = "app.storage.minio",
            name = "enabled",
            havingValue = "true"
    )
    public CurrentUserAvatarUseCase currentUserAvatarUseCase(
            UserRepository userRepository,
            UserAvatarImageProcessor imageProcessor,
            UserAvatarStorageKeyFactory storageKeyFactory,
            StorageService storageService,
            TransactionRollbackCoordinator rollbackCoordinator,
            StorageCleanupScheduler cleanupScheduler,
            StorageCleanupRecoveryScheduler recoveryScheduler
    ) {
        return new TransactionalCurrentUserAvatarService(
                userRepository,
                imageProcessor,
                storageKeyFactory,
                storageService,
                rollbackCoordinator,
                cleanupScheduler,
                recoveryScheduler
        );
    }
}
