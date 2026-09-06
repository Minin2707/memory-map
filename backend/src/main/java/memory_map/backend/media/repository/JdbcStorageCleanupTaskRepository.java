package memory_map.backend.media.repository;

import memory_map.backend.common.database.DatabaseTimestamps;
import memory_map.backend.media.application.StorageCleanupTask;
import memory_map.backend.media.storage.StorageKey;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.Collection;
import java.util.List;
import java.util.Objects;
import java.util.UUID;

@Repository
public class JdbcStorageCleanupTaskRepository
        implements StorageCleanupTaskRepository {

    private static final String INSERT_SQL = """
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
            ON CONFLICT (storage_key) DO NOTHING
            """;

    private static final String FIND_DUE_FOR_UPDATE_SQL = """
            SELECT
                id,
                storage_key,
                created_at,
                next_attempt_at,
                attempt_count
            FROM storage_cleanup_tasks
            WHERE next_attempt_at <= :currentTime
            ORDER BY next_attempt_at ASC, created_at ASC, id ASC
            LIMIT :limit
            FOR UPDATE SKIP LOCKED
            """;

    private static final String MARK_FAILED_SQL = """
            UPDATE storage_cleanup_tasks
            SET
                attempt_count = attempt_count + 1,
                next_attempt_at = :nextAttemptAt
            WHERE id = :taskId
            """;

    private static final String DELETE_SQL = """
            DELETE FROM storage_cleanup_tasks
            WHERE id = :taskId
            """;

    private final JdbcClient jdbcClient;
    private final StorageCleanupTaskRowMapper rowMapper;

    public JdbcStorageCleanupTaskRepository(JdbcClient jdbcClient) {
        this.jdbcClient = Objects.requireNonNull(
                jdbcClient,
                "jdbcClient must not be null"
        );
        this.rowMapper = new StorageCleanupTaskRowMapper();
    }

    @Override
    public void enqueue(StorageKey storageKey, Instant currentTime) {
        Objects.requireNonNull(storageKey, "storageKey must not be null");
        Objects.requireNonNull(currentTime, "currentTime must not be null");

        insert(storageKey, currentTime);
    }

    @Override
    public void enqueueAll(
            Collection<StorageKey> storageKeys,
            Instant currentTime
    ) {
        Objects.requireNonNull(storageKeys, "storageKeys must not be null");
        Objects.requireNonNull(currentTime, "currentTime must not be null");

        storageKeys.forEach(storageKey -> {
            Objects.requireNonNull(
                    storageKey,
                    "storageKeys must not contain null"
            );
            insert(storageKey, currentTime);
        });
    }

    @Override
    public List<StorageCleanupTask> findDueForUpdate(
            Instant currentTime,
            int limit
    ) {
        Objects.requireNonNull(currentTime, "currentTime must not be null");

        if (limit <= 0) {
            throw new IllegalArgumentException("limit must be positive");
        }

        return jdbcClient.sql(FIND_DUE_FOR_UPDATE_SQL)
                .param(
                        "currentTime",
                        DatabaseTimestamps.toOffsetDateTime(currentTime)
                )
                .param("limit", limit)
                .query(rowMapper)
                .list();
    }

    @Override
    public void markFailed(UUID taskId, Instant nextAttemptAt) {
        Objects.requireNonNull(taskId, "taskId must not be null");
        Objects.requireNonNull(
                nextAttemptAt,
                "nextAttemptAt must not be null"
        );

        jdbcClient.sql(MARK_FAILED_SQL)
                .param("taskId", taskId)
                .param(
                        "nextAttemptAt",
                        DatabaseTimestamps.toOffsetDateTime(nextAttemptAt)
                )
                .update();
    }

    @Override
    public void delete(UUID taskId) {
        Objects.requireNonNull(taskId, "taskId must not be null");

        jdbcClient.sql(DELETE_SQL)
                .param("taskId", taskId)
                .update();
    }

    private void insert(StorageKey storageKey, Instant currentTime) {
        jdbcClient.sql(INSERT_SQL)
                .param("id", UUID.randomUUID())
                .param("storageKey", storageKey.value())
                .param(
                        "createdAt",
                        DatabaseTimestamps.toOffsetDateTime(currentTime)
                )
                .param(
                        "nextAttemptAt",
                        DatabaseTimestamps.toOffsetDateTime(currentTime)
                )
                .update();
    }
}
