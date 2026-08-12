package memory_map.backend.media.application;

import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

import java.util.Objects;

public final class SpringTransactionRollbackCoordinator
        implements TransactionRollbackCoordinator {

    @Override
    public void onRollback(Runnable action) {
        Objects.requireNonNull(action, "action must not be null");

        if (!TransactionSynchronizationManager.isSynchronizationActive()) {
            throw new IllegalStateException(
                    "Transaction synchronization must be active"
            );
        }

        TransactionSynchronizationManager.registerSynchronization(
                new TransactionSynchronization() {

                    @Override
                    public void afterCompletion(int status) {
                        if (status != STATUS_ROLLED_BACK) {
                            return;
                        }

                        try {
                            action.run();
                        } catch (RuntimeException ignored) {
                            // Rollback has already happened; cleanup is best-effort.
                        }
                    }
                }
        );
    }
}
