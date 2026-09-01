package memory_map.backend.media.application;

import memory_map.backend.media.domain.MediaFile;
import memory_map.backend.media.image.ImageProcessingInput;
import memory_map.backend.media.image.ImageProcessor;
import memory_map.backend.media.image.ProcessedPhoto;
import memory_map.backend.media.repository.AuthorizedMediaDownloadRepository;
import memory_map.backend.media.repository.MediaFileRepository;
import memory_map.backend.media.storage.MediaStorageKeyFactory;
import memory_map.backend.media.storage.StorageByteRange;
import memory_map.backend.media.storage.StorageKey;
import memory_map.backend.media.storage.StorageObjectWrite;
import memory_map.backend.media.storage.StorageService;
import memory_map.backend.media.storage.StoredObject;
import memory_map.backend.memory.domain.Memory;
import memory_map.backend.memory.repository.MemoryRepository;
import memory_map.backend.notification.application.NotificationPublisher;
import memory_map.backend.storyparticipant.domain.StoryParticipant;
import memory_map.backend.storyparticipant.repository.StoryParticipantRepository;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

class MediaApplicationConfigurationTest {

    private final ApplicationContextRunner contextRunner =
            new ApplicationContextRunner()
                    .withUserConfiguration(
                            MediaApplicationConfiguration.class
                    )
                    .withBean(MemoryRepository.class, FakeMemoryRepository::new)
                    .withBean(
                            StoryParticipantRepository.class,
                            FakeStoryParticipantRepository::new
                    )
                    .withBean(
                            MediaFileRepository.class,
                            FakeMediaFileRepository::new
                    )
                    .withBean(
                            AuthorizedMediaDownloadRepository.class,
                            FakeAuthorizedMediaDownloadRepository::new
                    )
                    .withBean(ImageProcessor.class, FakeImageProcessor::new)
                    .withBean(
                            NotificationPublisher.class,
                            FakeNotificationPublisher::new
                    );

    @Test
    void shouldRegisterInfrastructureIndependentMediaBeans() {

        contextRunner.run(context -> {
            assertThat(context)
                    .hasSingleBean(PhotoUploadAuthorizationPolicy.class);
            assertThat(context)
                    .hasSingleBean(DeleteMediaAuthorizationPolicy.class);
            assertThat(context).hasSingleBean(MediaStorageKeyFactory.class);
            assertThat(context)
                    .hasSingleBean(TransactionRollbackCoordinator.class);
            assertThat(context)
                    .hasSingleBean(TransactionCommitCoordinator.class);
            assertThat(context).hasSingleBean(ListMemoryMediaUseCase.class);
            assertThat(context.getBean(ListMemoryMediaUseCase.class))
                    .isInstanceOf(TransactionalListMemoryMediaService.class);
        });
    }

    @Test
    void shouldNotRegisterUploadUseCaseWhenStorageServiceIsMissing() {

        contextRunner.run(context ->
                assertThat(context)
                        .doesNotHaveBean(UploadPhotoUseCase.class)
                        .doesNotHaveBean(DownloadMediaUseCase.class)
                        .doesNotHaveBean(DeleteMediaUseCase.class)
        );
    }

    @Test
    void shouldRegisterStorageBackedUseCasesWhenStorageIsAvailable() {

        contextRunner
                .withBean(FakeStorageService.class, FakeStorageService::new)
                .withPropertyValues("app.storage.minio.enabled=true")
                .run(context -> {
                    assertThat(context).hasSingleBean(UploadPhotoUseCase.class);
                    assertThat(context.getBean(UploadPhotoUseCase.class))
                            .isInstanceOf(CoordinatedUploadPhotoService.class);
                    assertThat(context)
                            .hasSingleBean(DownloadMediaUseCase.class);
                    assertThat(context.getBean(DownloadMediaUseCase.class))
                            .isInstanceOf(
                                    TransactionalDownloadMediaService.class
                            );
                    assertThat(context)
                            .hasSingleBean(DeleteMediaUseCase.class);
                    assertThat(context.getBean(DeleteMediaUseCase.class))
                            .isInstanceOf(
                                    TransactionalDeleteMediaService.class
                            );
                });
    }

    @Test
    void shouldNotTouchStorageWhenCreatingUploadUseCaseBean() {

        contextRunner
                .withBean(FakeStorageService.class, FakeStorageService::new)
                .withPropertyValues("app.storage.minio.enabled=true")
                .run(context -> {
                    FakeStorageService storageService =
                            context.getBean(FakeStorageService.class);

                    assertThat(context).hasSingleBean(UploadPhotoUseCase.class);
                    assertThat(storageService.storeCalls).isZero();
                    assertThat(storageService.deleteCalls).isZero();
                    assertThat(storageService.readCalls).isZero();
                });
    }

    private static final class FakeMemoryRepository
            implements MemoryRepository {

        @Override
        public Optional<Memory> findById(UUID id) {
            return Optional.empty();
        }

        @Override
        public Optional<Memory> findByIdForUpdate(UUID id) {
            return Optional.empty();
        }

        @Override
        public List<Memory> findByStoryId(UUID storyId) {
            return List.of();
        }

        @Override
        public void save(Memory memory) {
        }

        @Override
        public boolean update(Memory memory) {
            return false;
        }

        @Override
        public boolean delete(UUID id) {
            return false;
        }
    }

    private static final class FakeStoryParticipantRepository
            implements StoryParticipantRepository {

        @Override
        public Optional<StoryParticipant> find(UUID storyId, UUID userId) {
            return Optional.empty();
        }

        @Override
        public List<StoryParticipant> findByStoryId(UUID storyId) {
            return List.of();
        }

        @Override
        public List<StoryParticipant> findByUserId(UUID userId) {
            return List.of();
        }

        @Override
        public long countOwners(UUID storyId) {
            return 0;
        }

        @Override
        public boolean exists(UUID storyId, UUID userId) {
            return false;
        }

        @Override
        public void save(StoryParticipant participant) {
        }

        @Override
        public void update(StoryParticipant participant) {
        }

        @Override
        public void delete(UUID storyId, UUID userId) {
        }
    }

    private static final class FakeMediaFileRepository
            implements MediaFileRepository {

        @Override
        public Optional<MediaFile> findById(UUID id) {
            return Optional.empty();
        }

        @Override
        public List<MediaFile> findByMemoryId(UUID memoryId) {
            return List.of();
        }

        @Override
        public void save(MediaFile mediaFile) {
        }

        @Override
        public void delete(UUID id) {
        }
    }

    private static final class FakeAuthorizedMediaDownloadRepository
            implements AuthorizedMediaDownloadRepository {

        @Override
        public Optional<MediaDownloadReadModel> findAuthorizedDownload(
                UUID mediaId,
                UUID requesterUserId
        ) {
            return Optional.empty();
        }
    }

    private static final class FakeImageProcessor implements ImageProcessor {

        @Override
        public ProcessedPhoto process(ImageProcessingInput input) {
            throw new UnsupportedOperationException();
        }
    }

    private static final class FakeNotificationPublisher
            implements NotificationPublisher {

        @Override
        public void participantJoined(
                UUID storyId,
                UUID actorUserId,
                java.time.Instant createdAt
        ) {
        }

        @Override
        public void memoryCreated(
                Memory memory,
                java.time.Instant createdAt
        ) {
        }

        @Override
        public void photosAdded(
                Memory memory,
                UUID actorUserId,
                java.time.Instant createdAt
        ) {
        }
    }

    private static final class FakeStorageService implements StorageService {

        private int storeCalls;
        private int readCalls;
        private int deleteCalls;

        @Override
        public void store(StorageObjectWrite object) {
            storeCalls++;
        }

        @Override
        public StoredObject read(StorageKey storageKey) {
            readCalls++;
            throw new UnsupportedOperationException();
        }

        @Override
        public StoredObject readRange(
                StorageKey storageKey,
                StorageByteRange range
        ) {
            throw new UnsupportedOperationException();
        }

        @Override
        public void delete(StorageKey storageKey) {
            deleteCalls++;
        }
    }
}
