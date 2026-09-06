package memory_map.backend.media.application;

import memory_map.backend.IntegrationTest;
import memory_map.backend.media.storage.StorageKey;
import memory_map.backend.user.domain.User;
import memory_map.backend.user.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

class TransactionalStorageCleanupRecoverySchedulerIntegrationTest
        extends IntegrationTest {

    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000081");
    private static final Instant CURRENT_TIME =
            Instant.parse("2026-01-01T10:00:00Z");

    @Autowired
    private StorageCleanupRecoveryScheduler recoveryScheduler;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private JdbcClient jdbcClient;

    @Autowired
    private PlatformTransactionManager transactionManager;

    @BeforeEach
    void cleanDatabase() {
        jdbcClient.sql("TRUNCATE TABLE storage_cleanup_tasks, users CASCADE")
                .update();
    }

    @Test
    void shouldScheduleOutsideTransaction() {
        StorageKey storageKey = new StorageKey("media/recovery/display");

        recoveryScheduler.schedule(List.of(storageKey));

        assertThat(cleanupTaskKeys()).containsExactly(storageKey.value());
    }

    @Test
    void shouldCommitRecoveryTaskWhenOuterTransactionRollsBack() {
        StorageKey storageKey = new StorageKey("media/recovery/rollback");
        TransactionTemplate transactionTemplate =
                new TransactionTemplate(transactionManager);

        transactionTemplate.executeWithoutResult(status -> {
            userRepository.save(new User(
                    USER_ID,
                    "google-subject-recovery",
                    "Recovery User",
                    null,
                    CURRENT_TIME,
                    CURRENT_TIME
            ));
            recoveryScheduler.schedule(List.of(storageKey));
            status.setRollbackOnly();
        });

        assertThat(userRepository.findById(USER_ID)).isEmpty();
        assertThat(cleanupTaskKeys()).containsExactly(storageKey.value());
    }

    private List<String> cleanupTaskKeys() {
        return jdbcClient.sql("""
                SELECT storage_key
                FROM storage_cleanup_tasks
                ORDER BY storage_key
                """)
                .query(String.class)
                .list();
    }
}
