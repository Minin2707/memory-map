package memory_map.backend.media.application;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

import java.util.concurrent.atomic.AtomicInteger;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class SpringTransactionCommitCoordinatorTest {

    private final SpringTransactionCommitCoordinator coordinator =
            new SpringTransactionCommitCoordinator();

    @AfterEach
    void clearSynchronization() {
        if (TransactionSynchronizationManager.isSynchronizationActive()) {
            TransactionSynchronizationManager.clearSynchronization();
        }
    }

    @Test
    void shouldRegisterActionForCommitOnly() {
        AtomicInteger calls = new AtomicInteger();

        TransactionSynchronizationManager.initSynchronization();
        coordinator.onCommit(calls::incrementAndGet);

        assertThat(calls.get()).isZero();

        TransactionSynchronizationManager.getSynchronizations()
                .forEach(TransactionSynchronization::afterCommit);

        assertThat(calls.get()).isEqualTo(1);
    }

    @Test
    void shouldIgnoreCommitActionFailure() {
        TransactionSynchronizationManager.initSynchronization();
        coordinator.onCommit(() -> {
            throw new RuntimeException("cleanup failed");
        });

        assertThatCode(() -> TransactionSynchronizationManager
                .getSynchronizations()
                .forEach(TransactionSynchronization::afterCommit))
                .doesNotThrowAnyException();
    }

    @Test
    void shouldRejectNullAction() {
        assertThatThrownBy(() -> coordinator.onCommit(null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("action must not be null");
    }

    @Test
    void shouldRejectMissingTransactionSynchronization() {
        assertThatThrownBy(() -> coordinator.onCommit(() -> {
        }))
                .isInstanceOf(IllegalStateException.class)
                .hasMessage("Transaction synchronization must be active");
    }
}
