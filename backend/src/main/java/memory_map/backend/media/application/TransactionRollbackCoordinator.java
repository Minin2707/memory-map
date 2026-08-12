package memory_map.backend.media.application;

public interface TransactionRollbackCoordinator {

    void onRollback(Runnable action);
}
