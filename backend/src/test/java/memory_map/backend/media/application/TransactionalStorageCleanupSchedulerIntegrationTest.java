package memory_map.backend.media.application;

import memory_map.backend.IntegrationTest;
import memory_map.backend.media.storage.StorageKey;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.transaction.IllegalTransactionStateException;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class TransactionalStorageCleanupSchedulerIntegrationTest
        extends IntegrationTest {

    @Autowired
    private StorageCleanupScheduler scheduler;

    @Autowired
    private JdbcClient jdbcClient;

    @BeforeEach
    void cleanDatabase() {
        jdbcClient.sql("TRUNCATE TABLE storage_cleanup_tasks").update();
    }

    @Test
    void shouldFailClosedOutsideTransaction() {
        StorageKey storageKey = new StorageKey("media/test/display");

        assertThatThrownBy(() -> scheduler.schedule(List.of(storageKey)))
                .isInstanceOf(IllegalTransactionStateException.class);

        assertThat(cleanupTaskCount()).isZero();
    }

    private int cleanupTaskCount() {
        return jdbcClient.sql("""
                SELECT COUNT(*)
                FROM storage_cleanup_tasks
                """)
                .query(Long.class)
                .single()
                .intValue();
    }
}
