package memory_map.backend.memory.application;

import memory_map.backend.media.application.TransactionCommitCoordinator;
import memory_map.backend.media.domain.MediaFile;
import memory_map.backend.media.repository.MediaFileRepository;
import memory_map.backend.media.storage.StorageKey;
import memory_map.backend.media.storage.StorageObjectWrite;
import memory_map.backend.media.storage.StorageService;
import memory_map.backend.media.storage.StoredObject;
import memory_map.backend.memory.domain.Memory;
import memory_map.backend.memory.repository.MemoryReadRepository;
import memory_map.backend.memory.repository.MemoryRepository;
import memory_map.backend.storyparticipant.domain.StoryParticipant;
import memory_map.backend.storyparticipant.repository.StoryParticipantRepository;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

class MemoryApplicationConfigurationTest {

    private final ApplicationContextRunner contextRunner =
            new ApplicationContextRunner()
                    .withUserConfiguration(
                            MemoryApplicationConfiguration.class
                    )
                    .withBean(
                            StoryParticipantRepository.class,
                            FakeStoryParticipantRepository::new
                    )
                    .withBean(
                            MemoryRepository.class,
                            FakeMemoryRepository::new
                    )
                    .withBean(
                            MemoryReadRepository.class,
                            FakeMemoryReadRepository::new
                    )
                    .withBean(
                            MediaFileRepository.class,
                            FakeMediaFileRepository::new
                    )
                    .withBean(
                            TransactionCommitCoordinator.class,
                            FakeTransactionCommitCoordinator::new
                    );

    @Test
    void shouldRegisterCreateMemoryUseCaseBean() {

        contextRunner.run(context -> {
            assertThat(context).hasSingleBean(CreateMemoryUseCase.class);
            assertThat(context.getBean(CreateMemoryUseCase.class))
                    .isInstanceOf(TransactionalCreateMemoryService.class);
        });
    }

    @Test
    void shouldRegisterGetStoryMemoriesUseCaseBean() {

        contextRunner.run(context -> {
            assertThat(context).hasSingleBean(GetStoryMemoriesUseCase.class);
            assertThat(context.getBean(GetStoryMemoriesUseCase.class))
                    .isInstanceOf(DefaultGetStoryMemoriesService.class);
        });
    }

    @Test
    void shouldRegisterGetMemoryUseCaseBean() {

        contextRunner.run(context -> {
            assertThat(context).hasSingleBean(GetMemoryUseCase.class);
            assertThat(context.getBean(GetMemoryUseCase.class))
                    .isInstanceOf(DefaultGetMemoryService.class);
        });
    }

    @Test
    void shouldRegisterUpdateMemoryUseCaseBean() {

        contextRunner.run(context -> {
            assertThat(context).hasSingleBean(UpdateMemoryUseCase.class);
            assertThat(context.getBean(UpdateMemoryUseCase.class))
                    .isInstanceOf(TransactionalUpdateMemoryService.class);
        });
    }

    @Test
    void shouldRegisterDeleteMemoryUseCaseBean() {

        contextRunner.run(context -> {
            assertThat(context).hasSingleBean(DeleteMemoryUseCase.class);
            assertThat(context.getBean(DeleteMemoryUseCase.class))
                    .isInstanceOf(TransactionalDeleteMemoryService.class);
            assertThat(context)
                    .hasSingleBean(MemoryMediaCleanupCoordinator.class);
            assertThat(context.getBean(MemoryMediaCleanupCoordinator.class))
                    .isInstanceOf(
                            StorageUnavailableMemoryMediaCleanupCoordinator.class
                    );
        });
    }

    @Test
    void shouldUseStorageBackedCleanupWhenStorageServiceIsAvailable() {

        contextRunner
                .withBean(FakeStorageService.class, FakeStorageService::new)
                .run(context -> {
                    assertThat(context)
                            .hasSingleBean(MemoryMediaCleanupCoordinator.class);
                    assertThat(context.getBean(
                            MemoryMediaCleanupCoordinator.class
                    ))
                            .isInstanceOf(
                                    StorageBackedMemoryMediaCleanupCoordinator.class
                            );
                });
    }

    @Test
    void shouldKeepDeleteMemoryUseCaseAvailableWhenStorageServiceIsMissing() {

        contextRunner.run(context -> {
            assertThat(context).doesNotHaveBean(StorageService.class);
            assertThat(context).hasSingleBean(DeleteMemoryUseCase.class);
        });
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

    private static final class FakeMemoryReadRepository
            implements MemoryReadRepository {

        @Override
        public Optional<StoryMemoriesView> findByStoryIdAndRequesterUserId(
                UUID storyId,
                UUID requesterUserId
        ) {
            return Optional.empty();
        }

        @Override
        public Optional<Memory> findByIdAndRequesterUserId(
                UUID memoryId,
                UUID requesterUserId
        ) {
            return Optional.empty();
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

    private static final class FakeTransactionCommitCoordinator
            implements TransactionCommitCoordinator {

        @Override
        public void onCommit(Runnable action) {
        }
    }

    private static final class FakeStorageService implements StorageService {

        @Override
        public void store(StorageObjectWrite object) {
        }

        @Override
        public StoredObject read(StorageKey storageKey) {
            throw new UnsupportedOperationException();
        }

        @Override
        public void delete(StorageKey storageKey) {
        }
    }
}
