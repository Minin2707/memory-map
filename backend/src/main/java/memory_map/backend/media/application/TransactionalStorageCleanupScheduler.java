package memory_map.backend.media.application;

import memory_map.backend.media.repository.StorageCleanupTaskRepository;
import memory_map.backend.media.storage.StorageKey;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.util.Collection;
import java.util.Objects;

public class TransactionalStorageCleanupScheduler
        implements StorageCleanupScheduler {

    private final StorageCleanupTaskRepository repository;
    private final Clock clock;

    public TransactionalStorageCleanupScheduler(
            StorageCleanupTaskRepository repository,
            Clock clock
    ) {
        this.repository = Objects.requireNonNull(
                repository,
                "repository must not be null"
        );
        this.clock = Objects.requireNonNull(clock, "clock must not be null");
    }

    @Override
    @Transactional(propagation = Propagation.MANDATORY)
    public void schedule(Collection<StorageKey> storageKeys) {
        Objects.requireNonNull(storageKeys, "storageKeys must not be null");
        storageKeys.forEach(storageKey ->
                Objects.requireNonNull(
                        storageKey,
                        "storageKeys must not contain null"
                )
        );

        if (storageKeys.isEmpty()) {
            return;
        }

        repository.enqueueAll(storageKeys, clock.instant());
    }
}
