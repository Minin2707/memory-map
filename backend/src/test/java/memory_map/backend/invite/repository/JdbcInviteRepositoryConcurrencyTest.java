package memory_map.backend.invite.repository;

import memory_map.backend.IntegrationTest;
import memory_map.backend.invite.domain.Invite;
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
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class JdbcInviteRepositoryConcurrencyTest extends IntegrationTest {

    @Autowired
    private InviteRepository repository;

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

    private static final Instant EXPIRES_AT =
            BASE_TIME.plusSeconds(30L * 24 * 60 * 60);

    private static final Instant FIRST_USED_AT =
            BASE_TIME.plusSeconds(60);

    private static final Instant SECOND_USED_AT =
            BASE_TIME.plusSeconds(120);

    private static final String CLEAN_DATABASE_SQL = """
        TRUNCATE TABLE users
        RESTART IDENTITY CASCADE
        """;

    @BeforeEach
    void cleanDatabase() {
        jdbcClient.sql(CLEAN_DATABASE_SQL).update();
    }

    @Test
    void shouldSerializeLockedInviteConsumption() throws Exception {

        User user = saveUser("google-subject-123");
        Story story = saveStory(user);
        Invite invite = createInvite(
                story.id(),
                user.id(),
                "hash-invite-001"
        );
        TransactionTemplate transactionTemplate =
                new TransactionTemplate(transactionManager);
        ExecutorService executor = Executors.newFixedThreadPool(2);
        CountDownLatch firstLockAcquired = new CountDownLatch(1);
        CountDownLatch releaseFirstTransaction = new CountDownLatch(1);
        CountDownLatch secondLockAttemptStarted = new CountDownLatch(1);

        repository.save(invite);

        try {
            Future<LockAttemptResult> first = executor.submit(() ->
                    transactionTemplate.execute(status -> {
                        Invite locked = repository
                                .findByTokenHashForUpdate(invite.tokenHash())
                                .orElseThrow();
                        firstLockAcquired.countDown();
                        await(releaseFirstTransaction);

                        boolean marked = repository.markUsedIfUnused(
                                invite.id(),
                                FIRST_USED_AT
                        );

                        return new LockAttemptResult(locked, marked);
                    })
            );

            assertThat(firstLockAcquired.await(10, TimeUnit.SECONDS))
                    .isTrue();

            Future<LockAttemptResult> second = executor.submit(() ->
                    transactionTemplate.execute(status -> {
                        secondLockAttemptStarted.countDown();
                        Invite locked = repository
                                .findByTokenHashForUpdate(invite.tokenHash())
                                .orElseThrow();
                        boolean marked = repository.markUsedIfUnused(
                                invite.id(),
                                SECOND_USED_AT
                        );

                        return new LockAttemptResult(locked, marked);
                    })
            );

            assertThat(secondLockAttemptStarted.await(10, TimeUnit.SECONDS))
                    .isTrue();
            assertThatThrownBy(() -> second.get(250, TimeUnit.MILLISECONDS))
                    .isInstanceOf(TimeoutException.class);

            releaseFirstTransaction.countDown();

            LockAttemptResult firstResult =
                    first.get(10, TimeUnit.SECONDS);
            LockAttemptResult secondResult =
                    second.get(10, TimeUnit.SECONDS);
            Invite loaded = repository.findById(invite.id())
                    .orElseThrow();

            assertThat(firstResult.lockedInvite().usedAt()).isNull();
            assertThat(firstResult.marked()).isTrue();
            assertThat(secondResult.lockedInvite().usedAt())
                    .isEqualTo(FIRST_USED_AT);
            assertThat(secondResult.marked()).isFalse();
            assertThat(loaded.usedAt()).isEqualTo(FIRST_USED_AT);
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

    private Invite createInvite(
            UUID storyId,
            UUID createdBy,
            String tokenHash
    ) {
        return new Invite(
                UUID.randomUUID(),
                storyId,
                tokenHash,
                createdBy,
                BASE_TIME,
                EXPIRES_AT,
                null
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

    private record LockAttemptResult(
            Invite lockedInvite,
            boolean marked
    ) {
    }
}
