package memory_map.backend.memory.repository;

import memory_map.backend.IntegrationTest;
import memory_map.backend.memory.domain.Memory;
import memory_map.backend.story.domain.Story;
import memory_map.backend.story.repository.StoryRepository;
import memory_map.backend.user.domain.User;
import memory_map.backend.user.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class JdbcMemoryRepositoryConcurrencyTest extends IntegrationTest {

    @Autowired
    private MemoryRepository repository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private StoryRepository storyRepository;

    @Autowired
    private JdbcClient jdbcClient;

    @Autowired
    private PlatformTransactionManager transactionManager;

    private static final Instant BASE_TIME =
            Instant.parse("2026-01-01T10:00:00.123456Z");

    private static final Instant UPDATED_AT =
            BASE_TIME.plusSeconds(60);

    private static final String CLEAN_DATABASE_SQL = """
        TRUNCATE TABLE users
        RESTART IDENTITY CASCADE
        """;

    @BeforeEach
    void cleanDatabase() {
        jdbcClient.sql(CLEAN_DATABASE_SQL).update();
    }

    @Test
    void shouldSerializeLockedMemoryUpdatesAndExposeCommittedValue()
            throws Exception {

        User user = saveUser("google-subject-123");
        Story story = saveStory(user);
        Memory memory = createMemory(
                story.id(),
                user.id()
        );
        Memory updatedMemory = new Memory(
                memory.id(),
                memory.storyId(),
                memory.createdBy(),
                "Updated locked memory",
                memory.description(),
                memory.placeName(),
                memory.latitude(),
                memory.longitude(),
                memory.eventDate(),
                memory.createdAt(),
                UPDATED_AT
        );
        TransactionTemplate transactionTemplate =
                new TransactionTemplate(transactionManager);
        ExecutorService executor = Executors.newFixedThreadPool(2);
        CountDownLatch firstLockAcquired = new CountDownLatch(1);
        CountDownLatch releaseFirstTransaction = new CountDownLatch(1);
        CountDownLatch secondLockAttemptStarted = new CountDownLatch(1);

        repository.save(memory);

        try {
            Future<LockedMemoryUpdateResult> first = executor.submit(() ->
                    transactionTemplate.execute(status -> {
                        Memory locked = repository
                                .findByIdForUpdate(memory.id())
                                .orElseThrow();
                        firstLockAcquired.countDown();
                        await(releaseFirstTransaction);

                        boolean updated = repository.update(updatedMemory);

                        return new LockedMemoryUpdateResult(locked, updated);
                    })
            );

            assertThat(firstLockAcquired.await(10, TimeUnit.SECONDS))
                    .isTrue();

            Future<Memory> second = executor.submit(() ->
                    transactionTemplate.execute(status -> {
                        secondLockAttemptStarted.countDown();

                        return repository.findByIdForUpdate(memory.id())
                                .orElseThrow();
                    })
            );

            assertThat(secondLockAttemptStarted.await(10, TimeUnit.SECONDS))
                    .isTrue();
            assertThatThrownBy(() -> second.get(250, TimeUnit.MILLISECONDS))
                    .isInstanceOf(TimeoutException.class);

            releaseFirstTransaction.countDown();

            LockedMemoryUpdateResult firstResult =
                    first.get(10, TimeUnit.SECONDS);
            Memory secondLocked = second.get(10, TimeUnit.SECONDS);
            Memory loaded = repository.findById(memory.id())
                    .orElseThrow();

            assertThat(firstResult.lockedMemory()).isEqualTo(memory);
            assertThat(firstResult.updated()).isTrue();
            assertThat(secondLocked.title())
                    .isEqualTo(updatedMemory.title());
            assertThat(secondLocked.updatedAt())
                    .isEqualTo(updatedMemory.updatedAt());
            assertThat(loaded).isEqualTo(updatedMemory);
        } finally {
            releaseFirstTransaction.countDown();
            executor.shutdownNow();
        }
    }

    private User saveUser(String googleSubject) {
        return userRepository.save(
                new User(
                        UUID.randomUUID(),
                        googleSubject,
                        "Konstantin",
                        null,
                        BASE_TIME,
                        BASE_TIME
                )
        );
    }

    private Story saveStory(User owner) {
        return storyRepository.save(
                new Story(
                        UUID.randomUUID(),
                        owner.id(),
                        "Our Story",
                        "The beginning of our journey",
                        null,
                        BASE_TIME,
                        BASE_TIME
                )
        );
    }

    private Memory createMemory(
            UUID storyId,
            UUID createdBy
    ) {
        return new Memory(
                UUID.randomUUID(),
                storyId,
                createdBy,
                "First trip",
                "A spring walk",
                "Tbilisi",
                41.715137,
                44.827096,
                LocalDate.of(2024, 5, 20),
                BASE_TIME,
                BASE_TIME
        );
    }

    private static void await(CountDownLatch latch) {
        try {
            if (!latch.await(10, TimeUnit.SECONDS)) {
                throw new IllegalStateException("Timed out waiting for latch");
            }
        } catch (InterruptedException exception) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException(
                    "Interrupted while waiting",
                    exception
            );
        }
    }

    private record LockedMemoryUpdateResult(
            Memory lockedMemory,
            boolean updated
    ) {
    }
}
