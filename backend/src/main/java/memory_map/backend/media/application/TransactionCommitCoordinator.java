package memory_map.backend.media.application;

public interface TransactionCommitCoordinator {

    void onCommit(Runnable action);
}
