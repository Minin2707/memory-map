package memory_map.backend.media.application;

import memory_map.backend.media.storage.StorageKey;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class StorageCleanupTaskTest {

    private static final UUID TASK_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final StorageKey STORAGE_KEY =
            new StorageKey("users/private/avatar");
    private static final Instant CURRENT_TIME =
            Instant.parse("2026-01-01T10:00:00Z");

    @Test
    void shouldCreateCleanupTask() {
        StorageCleanupTask task = new StorageCleanupTask(
                TASK_ID,
                STORAGE_KEY,
                CURRENT_TIME,
                CURRENT_TIME,
                0
        );

        assertThat(task.id()).isEqualTo(TASK_ID);
        assertThat(task.storageKey()).isEqualTo(STORAGE_KEY);
        assertThat(task.createdAt()).isEqualTo(CURRENT_TIME);
        assertThat(task.nextAttemptAt()).isEqualTo(CURRENT_TIME);
        assertThat(task.attemptCount()).isZero();
    }

    @Test
    void shouldRejectMissingRequiredValues() {
        assertThatThrownBy(() -> new StorageCleanupTask(
                null,
                STORAGE_KEY,
                CURRENT_TIME,
                CURRENT_TIME,
                0
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("id must not be null");

        assertThatThrownBy(() -> new StorageCleanupTask(
                TASK_ID,
                null,
                CURRENT_TIME,
                CURRENT_TIME,
                0
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("storageKey must not be null");
    }

    @Test
    void shouldRejectNegativeAttemptCount() {
        assertThatThrownBy(() -> new StorageCleanupTask(
                TASK_ID,
                STORAGE_KEY,
                CURRENT_TIME,
                CURRENT_TIME,
                -1
        ))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("attemptCount must not be negative");
    }

    @Test
    void shouldNotExposeStorageKeyInDiagnostics() {
        StorageCleanupTask task = new StorageCleanupTask(
                TASK_ID,
                STORAGE_KEY,
                CURRENT_TIME,
                CURRENT_TIME,
                1
        );

        assertThat(task.toString())
                .contains(TASK_ID.toString())
                .contains("hasStorageKey=true")
                .doesNotContain(STORAGE_KEY.value());
    }
}
