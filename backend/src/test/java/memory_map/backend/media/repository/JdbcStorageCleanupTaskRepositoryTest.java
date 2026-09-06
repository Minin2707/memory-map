package memory_map.backend.media.repository;

import memory_map.backend.IntegrationTest;
import memory_map.backend.media.application.StorageCleanupTask;
import memory_map.backend.media.storage.StorageKey;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class JdbcStorageCleanupTaskRepositoryTest extends IntegrationTest {

    private static final Instant BASE_TIME =
            Instant.parse("2026-01-01T10:00:00Z");

    @Autowired
    private StorageCleanupTaskRepository repository;

    @Autowired
    private JdbcClient jdbcClient;

    @Autowired
    private PlatformTransactionManager transactionManager;

    @BeforeEach
    void cleanDatabase() {
        jdbcClient.sql("TRUNCATE TABLE storage_cleanup_tasks").update();
    }

    @Test
    void shouldEnqueueTask() {
        StorageKey storageKey = new StorageKey("media/one/display");

        repository.enqueue(storageKey, BASE_TIME);

        StorageCleanupTask task = taskByStorageKey(storageKey).orElseThrow();
        assertThat(task.storageKey()).isEqualTo(storageKey);
        assertThat(task.createdAt()).isEqualTo(BASE_TIME);
        assertThat(task.nextAttemptAt()).isEqualTo(BASE_TIME);
        assertThat(task.attemptCount()).isZero();
    }

    @Test
    void shouldTreatDuplicateStorageKeyAsIdempotent() {
        StorageKey storageKey = new StorageKey("media/one/display");

        repository.enqueue(storageKey, BASE_TIME);
        repository.enqueue(storageKey, BASE_TIME.plusSeconds(60));

        assertThat(taskCount()).isEqualTo(1);
        StorageCleanupTask task = taskByStorageKey(storageKey).orElseThrow();
        assertThat(task.createdAt()).isEqualTo(BASE_TIME);
    }

    @Test
    void shouldEnqueueMultipleTasks() {
        repository.enqueueAll(List.of(
                new StorageKey("media/one/display"),
                new StorageKey("media/two/display")
        ), BASE_TIME);

        assertThat(taskCount()).isEqualTo(2);
    }

    @Test
    void shouldSelectDueTasksOnly() {
        insertTask("media/due/display", BASE_TIME, BASE_TIME);
        insertTask(
                "media/future/display",
                BASE_TIME,
                BASE_TIME.plusSeconds(60)
        );

        List<StorageCleanupTask> tasks =
                repository.findDueForUpdate(BASE_TIME, 10);

        assertThat(tasks)
                .extracting(task -> task.storageKey().value())
                .containsExactly("media/due/display");
    }

    @Test
    void shouldSelectDueTasksInDeterministicOrder() {
        UUID thirdId =
                UUID.fromString("00000000-0000-0000-0000-000000000003");
        UUID firstId =
                UUID.fromString("00000000-0000-0000-0000-000000000001");
        UUID secondId =
                UUID.fromString("00000000-0000-0000-0000-000000000002");
        insertTask(
                thirdId,
                "media/third/display",
                BASE_TIME,
                BASE_TIME.plusSeconds(5)
        );
        insertTask(
                secondId,
                "media/second/display",
                BASE_TIME,
                BASE_TIME
        );
        insertTask(
                firstId,
                "media/first/display",
                BASE_TIME.minusSeconds(1),
                BASE_TIME
        );

        List<StorageCleanupTask> tasks =
                repository.findDueForUpdate(BASE_TIME.plusSeconds(10), 10);

        assertThat(tasks)
                .extracting(task -> task.storageKey().value())
                .containsExactly(
                        "media/first/display",
                        "media/second/display",
                        "media/third/display"
                );
    }

    @Test
    void shouldRespectBoundedSelection() {
        insertTask("media/one/display", BASE_TIME, BASE_TIME);
        insertTask("media/two/display", BASE_TIME, BASE_TIME);
        insertTask("media/three/display", BASE_TIME, BASE_TIME);

        List<StorageCleanupTask> tasks =
                repository.findDueForUpdate(BASE_TIME, 2);

        assertThat(tasks).hasSize(2);
    }

    @Test
    void shouldSkipTaskLockedByConcurrentTransaction() throws Exception {
        UUID taskAId =
                UUID.fromString("00000000-0000-0000-0000-000000000001");
        UUID taskBId =
                UUID.fromString("00000000-0000-0000-0000-000000000002");
        insertTask(
                taskAId,
                "media/a/display",
                BASE_TIME,
                BASE_TIME
        );
        insertTask(
                taskBId,
                "media/b/display",
                BASE_TIME.plusSeconds(1),
                BASE_TIME
        );
        TransactionTemplate transactionTemplate =
                new TransactionTemplate(transactionManager);
        ExecutorService executor = Executors.newFixedThreadPool(2);
        CountDownLatch firstTaskLocked = new CountDownLatch(1);
        CountDownLatch releaseFirstTransaction = new CountDownLatch(1);

        try {
            Future<List<StorageCleanupTask>> firstTransaction =
                    executor.submit(() -> transactionTemplate.execute(status -> {
                        List<StorageCleanupTask> tasks =
                                repository.findDueForUpdate(BASE_TIME, 1);

                        assertThat(tasks).hasSize(1);
                        assertThat(tasks.getFirst().id()).isEqualTo(taskAId);
                        firstTaskLocked.countDown();
                        await(releaseFirstTransaction);

                        return tasks;
                    }));

            assertThat(firstTaskLocked.await(10, TimeUnit.SECONDS)).isTrue();

            Future<List<StorageCleanupTask>> secondTransaction =
                    executor.submit(() -> transactionTemplate.execute(
                            status -> repository.findDueForUpdate(BASE_TIME, 1)
                    ));

            List<StorageCleanupTask> secondSelection =
                    secondTransaction.get(2, TimeUnit.SECONDS);

            assertThat(firstTransaction.isDone()).isFalse();
            assertThat(secondSelection).hasSize(1);
            assertThat(secondSelection.getFirst().id()).isEqualTo(taskBId);
            assertThat(secondSelection.getFirst().id()).isNotEqualTo(taskAId);
            assertThat(secondSelection.getFirst().storageKey())
                    .isNotEqualTo(new StorageKey("media/a/display"));

            releaseFirstTransaction.countDown();
            List<StorageCleanupTask> firstSelection =
                    firstTransaction.get(10, TimeUnit.SECONDS);

            assertThat(firstSelection).hasSize(1);
            assertThat(firstSelection.getFirst().id()).isEqualTo(taskAId);
            assertThat(firstSelection.getFirst().storageKey())
                    .isNotEqualTo(secondSelection.getFirst().storageKey());
        } finally {
            releaseFirstTransaction.countDown();
            executor.shutdownNow();
        }
    }

    @Test
    void shouldDeleteProcessedTask() {
        StorageKey storageKey = new StorageKey("media/one/display");
        repository.enqueue(storageKey, BASE_TIME);
        StorageCleanupTask task = taskByStorageKey(storageKey).orElseThrow();

        repository.delete(task.id());

        assertThat(taskCount()).isZero();
    }

    @Test
    void shouldRescheduleFailedAttempt() {
        StorageKey storageKey = new StorageKey("media/one/display");
        Instant nextAttemptAt = BASE_TIME.plusSeconds(30);
        repository.enqueue(storageKey, BASE_TIME);
        StorageCleanupTask task = taskByStorageKey(storageKey).orElseThrow();

        repository.markFailed(task.id(), nextAttemptAt);

        StorageCleanupTask updated =
                taskByStorageKey(storageKey).orElseThrow();
        assertThat(updated.attemptCount()).isEqualTo(1);
        assertThat(updated.nextAttemptAt()).isEqualTo(nextAttemptAt);
    }

    @Test
    void shouldRollbackEnqueueWithTransaction() {
        TransactionTemplate transactionTemplate =
                new TransactionTemplate(transactionManager);

        transactionTemplate.executeWithoutResult(status -> {
            repository.enqueue(new StorageKey("media/one/display"), BASE_TIME);
            status.setRollbackOnly();
        });

        assertThat(taskCount()).isZero();
    }

    @Test
    void shouldValidateRepositoryInputs() {
        assertThatThrownBy(() -> repository.enqueue(null, BASE_TIME))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("storageKey must not be null");

        assertThatThrownBy(() -> repository.enqueue(
                new StorageKey("media/one/display"),
                null
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("currentTime must not be null");

        assertThatThrownBy(() -> repository.findDueForUpdate(BASE_TIME, 0))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("limit must be positive");
    }

    private Optional<StorageCleanupTask> taskByStorageKey(
            StorageKey storageKey
    ) {
        return jdbcClient.sql("""
                SELECT
                    id,
                    storage_key,
                    created_at,
                    next_attempt_at,
                    attempt_count
                FROM storage_cleanup_tasks
                WHERE storage_key = :storageKey
                """)
                .param("storageKey", storageKey.value())
                .query(new StorageCleanupTaskRowMapper())
                .optional();
    }

    private long taskCount() {
        return jdbcClient.sql("""
                SELECT COUNT(*)
                FROM storage_cleanup_tasks
                """)
                .query(Long.class)
                .single();
    }

    private void insertTask(
            String storageKey,
            Instant createdAt,
            Instant nextAttemptAt
    ) {
        insertTask(
                UUID.randomUUID(),
                storageKey,
                createdAt,
                nextAttemptAt
        );
    }

    private void insertTask(
            UUID id,
            String storageKey,
            Instant createdAt,
            Instant nextAttemptAt
    ) {
        jdbcClient.sql("""
                INSERT INTO storage_cleanup_tasks (
                    id,
                    storage_key,
                    created_at,
                    next_attempt_at,
                    attempt_count
                )
                VALUES (
                    :id,
                    :storageKey,
                    :createdAt,
                    :nextAttemptAt,
                    0
                )
                """)
                .param("id", id)
                .param("storageKey", storageKey)
                .param("createdAt", toOffsetDateTime(createdAt))
                .param("nextAttemptAt", toOffsetDateTime(nextAttemptAt))
                .update();
    }

    private static OffsetDateTime toOffsetDateTime(Instant instant) {
        return OffsetDateTime.ofInstant(instant, ZoneOffset.UTC);
    }

    private static void await(CountDownLatch latch) {
        try {
            if (!latch.await(10, TimeUnit.SECONDS)) {
                throw new IllegalStateException("Timed out waiting");
            }
        } catch (InterruptedException exception) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException("Interrupted while waiting");
        }
    }
}
