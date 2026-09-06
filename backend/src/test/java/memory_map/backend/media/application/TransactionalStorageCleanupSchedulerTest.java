package memory_map.backend.media.application;

import memory_map.backend.media.repository.StorageCleanupTaskRepository;
import memory_map.backend.media.storage.StorageKey;
import org.junit.jupiter.api.Test;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.lang.reflect.Method;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.Collection;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class TransactionalStorageCleanupSchedulerTest {

    private static final Instant CURRENT_TIME =
            Instant.parse("2026-01-01T10:00:00Z");
    private static final Clock CLOCK =
            Clock.fixed(CURRENT_TIME, ZoneOffset.UTC);

    @Test
    void shouldScheduleOneKeyUsingRepositoryClock() {
        FakeStorageCleanupTaskRepository repository =
                new FakeStorageCleanupTaskRepository();
        TransactionalStorageCleanupScheduler scheduler =
                new TransactionalStorageCleanupScheduler(repository, CLOCK);
        StorageKey storageKey = new StorageKey("users/user-id/avatar/object");

        scheduler.schedule(List.of(storageKey));

        assertThat(repository.calls()).containsExactly(
                new EnqueueCall(List.of(storageKey), CURRENT_TIME)
        );
    }

    @Test
    void shouldScheduleMultipleKeysUsingRepositoryClock() {
        FakeStorageCleanupTaskRepository repository =
                new FakeStorageCleanupTaskRepository();
        TransactionalStorageCleanupScheduler scheduler =
                new TransactionalStorageCleanupScheduler(repository, CLOCK);
        StorageKey first = new StorageKey("stories/story-id/cover/display");
        StorageKey second = new StorageKey("memories/memory-id/media/thumb");

        scheduler.schedule(List.of(first, second));

        assertThat(repository.calls()).containsExactly(
                new EnqueueCall(List.of(first, second), CURRENT_TIME)
        );
    }

    @Test
    void shouldIgnoreEmptyCleanupSet() {
        FakeStorageCleanupTaskRepository repository =
                new FakeStorageCleanupTaskRepository();
        TransactionalStorageCleanupScheduler scheduler =
                new TransactionalStorageCleanupScheduler(repository, CLOCK);

        scheduler.schedule(List.of());

        assertThat(repository.calls()).isEmpty();
    }

    @Test
    void shouldRejectNullCollectionAndElements() {
        FakeStorageCleanupTaskRepository repository =
                new FakeStorageCleanupTaskRepository();
        TransactionalStorageCleanupScheduler scheduler =
                new TransactionalStorageCleanupScheduler(repository, CLOCK);

        assertThatThrownBy(() -> scheduler.schedule(null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("storageKeys must not be null");
        List<StorageKey> storageKeys = new ArrayList<>();
        storageKeys.add(new StorageKey("valid-key"));
        storageKeys.add(null);

        assertThatThrownBy(() -> scheduler.schedule(storageKeys))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("storageKeys must not contain null");
        assertThat(repository.calls()).isEmpty();
    }

    @Test
    void shouldPropagateRepositoryFailure() {
        FakeStorageCleanupTaskRepository repository =
                new FakeStorageCleanupTaskRepository();
        RuntimeException failure = new RuntimeException("enqueue failed");
        repository.failure = failure;
        TransactionalStorageCleanupScheduler scheduler =
                new TransactionalStorageCleanupScheduler(repository, CLOCK);

        assertThatThrownBy(() -> scheduler.schedule(List.of(
                new StorageKey("cleanup-key")
        )))
                .isSameAs(failure);
    }

    @Test
    void shouldRequireActiveTransactionForScheduling() throws Exception {
        Method schedule = TransactionalStorageCleanupScheduler.class
                .getMethod("schedule", Collection.class);

        Transactional transactional =
                schedule.getAnnotation(Transactional.class);

        assertThat(transactional).isNotNull();
        assertThat(transactional.propagation())
                .isEqualTo(Propagation.MANDATORY);
    }

    @Test
    void shouldRejectMissingDependencies() {
        FakeStorageCleanupTaskRepository repository =
                new FakeStorageCleanupTaskRepository();

        assertThatThrownBy(() -> new TransactionalStorageCleanupScheduler(
                null,
                CLOCK
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("repository must not be null");
        assertThatThrownBy(() -> new TransactionalStorageCleanupScheduler(
                repository,
                null
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("clock must not be null");
    }

    private record EnqueueCall(
            List<StorageKey> storageKeys,
            Instant currentTime
    ) {
    }

    private static final class FakeStorageCleanupTaskRepository
            implements StorageCleanupTaskRepository {

        private final List<EnqueueCall> calls = new ArrayList<>();
        private RuntimeException failure;

        @Override
        public void enqueue(StorageKey storageKey, Instant currentTime) {
            throw new UnsupportedOperationException();
        }

        @Override
        public void enqueueAll(
                Collection<StorageKey> storageKeys,
                Instant currentTime
        ) {
            if (failure != null) {
                throw failure;
            }
            calls.add(new EnqueueCall(List.copyOf(storageKeys), currentTime));
        }

        @Override
        public List<StorageCleanupTask> findDueForUpdate(
                Instant currentTime,
                int limit
        ) {
            throw new UnsupportedOperationException();
        }

        @Override
        public void markFailed(UUID taskId, Instant nextAttemptAt) {
            throw new UnsupportedOperationException();
        }

        @Override
        public void delete(UUID taskId) {
            throw new UnsupportedOperationException();
        }

        private List<EnqueueCall> calls() {
            return calls;
        }
    }
}
