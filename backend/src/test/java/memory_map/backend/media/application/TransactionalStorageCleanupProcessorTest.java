package memory_map.backend.media.application;

import memory_map.backend.media.repository.StorageCleanupTaskRepository;
import memory_map.backend.media.storage.StorageByteRange;
import memory_map.backend.media.storage.StorageException;
import memory_map.backend.media.storage.StorageKey;
import memory_map.backend.media.storage.StorageObjectWrite;
import memory_map.backend.media.storage.StorageService;
import memory_map.backend.media.storage.StoredObject;
import org.junit.jupiter.api.Test;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.Collection;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

class TransactionalStorageCleanupProcessorTest {

    private static final Instant CURRENT_TIME =
            Instant.parse("2026-01-01T10:00:00Z");
    private static final Instant NEXT_ATTEMPT =
            Instant.parse("2026-01-01T10:00:30Z");
    private static final Clock CLOCK =
            Clock.fixed(CURRENT_TIME, ZoneOffset.UTC);

    @Test
    void shouldRemoveTaskAfterSuccessfulStorageDelete() {
        FakeStorageCleanupTaskRepository repository =
                new FakeStorageCleanupTaskRepository(List.of(task("one", 0)));
        FakeStorageService storageService = new FakeStorageService();
        TransactionalStorageCleanupProcessor processor = processor(
                repository,
                storageService
        );

        int processed = processor.processDueTasks();

        assertThat(processed).isEqualTo(1);
        assertThat(storageService.deletedKeys()).containsExactly("key-one");
        assertThat(repository.deletedTaskIds())
                .containsExactly(repository.tasks().getFirst().id());
        assertThat(repository.failedTaskIds()).isEmpty();
    }

    @Test
    void shouldTreatMissingStorageObjectAsSuccessfulWhenDeleteCompletes() {
        FakeStorageCleanupTaskRepository repository =
                new FakeStorageCleanupTaskRepository(List.of(task("one", 0)));
        FakeStorageService storageService = new FakeStorageService();
        TransactionalStorageCleanupProcessor processor = processor(
                repository,
                storageService
        );

        processor.processDueTasks();

        assertThat(storageService.deletedKeys()).containsExactly("key-one");
        assertThat(repository.deletedTaskIds())
                .containsExactly(repository.tasks().getFirst().id());
        assertThat(repository.failedTaskIds()).isEmpty();
    }

    @Test
    void shouldRescheduleTaskAfterStorageFailure() {
        StorageCleanupTask task = task("one", 2);
        FakeStorageCleanupTaskRepository repository =
                new FakeStorageCleanupTaskRepository(List.of(task));
        FakeStorageService storageService = new FakeStorageService();
        storageService.failKey("key-one");
        TransactionalStorageCleanupProcessor processor = processor(
                repository,
                storageService
        );

        processor.processDueTasks();

        assertThat(storageService.deletedKeys()).containsExactly("key-one");
        assertThat(repository.deletedTaskIds()).isEmpty();
        assertThat(repository.failedTaskIds()).containsExactly(task.id());
        assertThat(repository.failedNextAttemptAt())
                .containsExactly(NEXT_ATTEMPT);
    }

    @Test
    void shouldContinueProcessingAnotherTaskAfterStorageFailure() {
        StorageCleanupTask failedTask = task("one", 0);
        StorageCleanupTask successfulTask = task("two", 0);
        FakeStorageCleanupTaskRepository repository =
                new FakeStorageCleanupTaskRepository(List.of(
                        failedTask,
                        successfulTask
                ));
        FakeStorageService storageService = new FakeStorageService();
        storageService.failKey("key-one");
        TransactionalStorageCleanupProcessor processor = processor(
                repository,
                storageService
        );

        processor.processDueTasks();

        assertThat(storageService.deletedKeys())
                .containsExactly("key-one", "key-two");
        assertThat(repository.failedTaskIds()).containsExactly(failedTask.id());
        assertThat(repository.deletedTaskIds())
                .containsExactly(successfulTask.id());
    }

    private static TransactionalStorageCleanupProcessor processor(
            FakeStorageCleanupTaskRepository repository,
            FakeStorageService storageService
    ) {
        return new TransactionalStorageCleanupProcessor(
                repository,
                storageService,
                CLOCK
        );
    }

    private static StorageCleanupTask task(String suffix, int attemptCount) {
        return new StorageCleanupTask(
                UUID.nameUUIDFromBytes(suffix.getBytes()),
                new StorageKey("key-" + suffix),
                CURRENT_TIME,
                CURRENT_TIME,
                attemptCount
        );
    }

    private static final class FakeStorageCleanupTaskRepository
            implements StorageCleanupTaskRepository {

        private final List<StorageCleanupTask> tasks;
        private final List<UUID> deletedTaskIds = new ArrayList<>();
        private final List<UUID> failedTaskIds = new ArrayList<>();
        private final List<Instant> failedNextAttemptAt = new ArrayList<>();

        private FakeStorageCleanupTaskRepository(
                List<StorageCleanupTask> tasks
        ) {
            this.tasks = tasks;
        }

        @Override
        public void enqueue(StorageKey storageKey, Instant currentTime) {
            throw new UnsupportedOperationException();
        }

        @Override
        public void enqueueAll(
                Collection<StorageKey> storageKeys,
                Instant currentTime
        ) {
            throw new UnsupportedOperationException();
        }

        @Override
        public List<StorageCleanupTask> findDueForUpdate(
                Instant currentTime,
                int limit
        ) {
            assertThat(currentTime).isEqualTo(CURRENT_TIME);
            assertThat(limit).isEqualTo(25);

            return tasks;
        }

        @Override
        public void markFailed(UUID taskId, Instant nextAttemptAt) {
            failedTaskIds.add(taskId);
            failedNextAttemptAt.add(nextAttemptAt);
        }

        @Override
        public void delete(UUID taskId) {
            deletedTaskIds.add(taskId);
        }

        private List<StorageCleanupTask> tasks() {
            return tasks;
        }

        private List<UUID> deletedTaskIds() {
            return deletedTaskIds;
        }

        private List<UUID> failedTaskIds() {
            return failedTaskIds;
        }

        private List<Instant> failedNextAttemptAt() {
            return failedNextAttemptAt;
        }
    }

    private static final class FakeStorageService implements StorageService {

        private final List<String> deletedKeys = new ArrayList<>();
        private String failingKey;

        @Override
        public void store(StorageObjectWrite object) {
            throw new UnsupportedOperationException();
        }

        @Override
        public StoredObject read(StorageKey storageKey) {
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
            deletedKeys.add(storageKey.value());

            if (storageKey.value().equals(failingKey)) {
                throw new StorageException();
            }
        }

        private void failKey(String storageKey) {
            failingKey = storageKey;
        }

        private List<String> deletedKeys() {
            return deletedKeys;
        }
    }
}
