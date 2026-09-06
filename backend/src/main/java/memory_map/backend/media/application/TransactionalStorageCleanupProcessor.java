package memory_map.backend.media.application;

import memory_map.backend.media.repository.StorageCleanupTaskRepository;
import memory_map.backend.media.storage.StorageService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Objects;

public class TransactionalStorageCleanupProcessor
        implements StorageCleanupProcessor {

    private static final Logger LOGGER =
            LoggerFactory.getLogger(TransactionalStorageCleanupProcessor.class);
    private static final int BATCH_SIZE = 25;
    private static final Duration RETRY_DELAY = Duration.ofSeconds(30);

    private final StorageCleanupTaskRepository repository;
    private final StorageService storageService;
    private final Clock clock;

    public TransactionalStorageCleanupProcessor(
            StorageCleanupTaskRepository repository,
            StorageService storageService,
            Clock clock
    ) {
        this.repository = Objects.requireNonNull(
                repository,
                "repository must not be null"
        );
        this.storageService = Objects.requireNonNull(
                storageService,
                "storageService must not be null"
        );
        this.clock = Objects.requireNonNull(clock, "clock must not be null");
    }

    @Override
    @Transactional
    public int processDueTasks() {
        Instant now = clock.instant();
        List<StorageCleanupTask> tasks =
                repository.findDueForUpdate(now, BATCH_SIZE);

        for (StorageCleanupTask task : tasks) {
            processTask(task);
        }

        return tasks.size();
    }

    private void processTask(StorageCleanupTask task) {
        try {
            storageService.delete(task.storageKey());
            repository.delete(task.id());
        } catch (RuntimeException exception) {
            int failedAttempt = task.attemptCount() + 1;
            repository.markFailed(
                    task.id(),
                    clock.instant().plus(RETRY_DELAY)
            );
            LOGGER.warn(
                    "Storage cleanup task {} failed on attempt {} with {}",
                    task.id(),
                    failedAttempt,
                    exception.getClass().getName()
            );
        }
    }
}
