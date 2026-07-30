package memory_map.backend.auth.repository;

import memory_map.backend.IntegrationTest;
import memory_map.backend.auth.domain.RefreshToken;
import memory_map.backend.user.domain.User;
import memory_map.backend.user.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.jdbc.core.simple.JdbcClient;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import java.util.concurrent.Callable;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class JdbcRefreshTokenRepositoryTest extends IntegrationTest {

    @Autowired
    private RefreshTokenRepository repository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private JdbcClient jdbcClient;

    private static final Instant BASE_TIME =
            Instant.parse("2026-01-01T10:00:00.123456Z");

    private static final Instant EXPIRES_AT =
            BASE_TIME.plusSeconds(30L * 24 * 60 * 60);

    private static final Instant REVOKED_AT =
            BASE_TIME.plusSeconds(60);

    private static final Instant FIRST_REVOKED_AT =
            BASE_TIME.plusSeconds(120);

    private static final Instant SECOND_REVOKED_AT =
            BASE_TIME.plusSeconds(180);

    private static final String CLEAN_DATABASE_SQL = """
        TRUNCATE TABLE users
        RESTART IDENTITY CASCADE
        """;

    @BeforeEach
    void cleanDatabase() {
        jdbcClient.sql(CLEAN_DATABASE_SQL).update();
    }

    private User createUser(String googleSubject) {
        return new User(
                UUID.randomUUID(),
                googleSubject,
                "Konstantin",
                null,
                BASE_TIME,
                BASE_TIME
        );
    }

    private User saveUser(String googleSubject) {
        return userRepository.save(
                createUser(googleSubject)
        );
    }

    private RefreshToken createRefreshToken(
            UUID userId,
            String tokenHash
    ) {
        return createRefreshToken(
                UUID.randomUUID(),
                userId,
                tokenHash,
                BASE_TIME,
                EXPIRES_AT,
                null
        );
    }

    private RefreshToken createRefreshToken(
            UUID id,
            UUID userId,
            String tokenHash,
            Instant createdAt,
            Instant expiresAt,
            Instant revokedAt
    ) {
        return new RefreshToken(
                id,
                userId,
                tokenHash,
                createdAt,
                expiresAt,
                revokedAt
        );
    }

    private RefreshToken createRevokedRefreshToken(
            UUID userId,
            String tokenHash
    ) {
        return createRefreshToken(
                UUID.randomUUID(),
                userId,
                tokenHash,
                BASE_TIME,
                EXPIRES_AT,
                BASE_TIME.plusSeconds(60)
        );
    }

    private void assertRefreshTokenMatches(
            RefreshToken actual,
            RefreshToken expected
    ) {
        assertThat(actual.id()).isEqualTo(expected.id());
        assertThat(actual.userId()).isEqualTo(expected.userId());
        assertThat(actual.tokenHash()).isEqualTo(expected.tokenHash());
        assertThat(actual.createdAt()).isEqualTo(expected.createdAt());
        assertThat(actual.expiresAt()).isEqualTo(expected.expiresAt());
        assertThat(actual.revokedAt()).isEqualTo(expected.revokedAt());
    }

    @Test
    void shouldSaveAndFindRefreshTokenById() {

        User user = saveUser("google-subject-123");
        RefreshToken refreshToken = createRefreshToken(
                user.id(),
                "hash-refresh-001"
        );

        repository.save(refreshToken);

        RefreshToken loaded = repository.findById(refreshToken.id())
                .orElseThrow();

        assertRefreshTokenMatches(loaded, refreshToken);
    }

    @Test
    void shouldFindRefreshTokenByTokenHash() {

        User user = saveUser("google-subject-123");
        RefreshToken first = createRefreshToken(
                user.id(),
                "hash-refresh-001"
        );
        RefreshToken second = createRefreshToken(
                user.id(),
                "hash-refresh-002"
        );

        repository.save(first);
        repository.save(second);

        Optional<RefreshToken> found =
                repository.findByTokenHash(first.tokenHash());

        assertThat(found)
                .contains(first);

        assertThat(repository.findByTokenHash("hash-refresh-missing"))
                .isEmpty();
    }

    @Test
    void shouldReturnEmptyWhenRefreshTokenDoesNotExist() {

        Optional<RefreshToken> found =
                repository.findById(UUID.randomUUID());

        assertThat(found).isEmpty();
    }

    @Test
    void shouldFindRefreshTokensByUserId() {

        User firstUser = saveUser("first-google-subject");
        User secondUser = saveUser("second-google-subject");
        RefreshToken first = createRefreshToken(
                firstUser.id(),
                "hash-refresh-001"
        );
        RefreshToken second = createRefreshToken(
                UUID.randomUUID(),
                firstUser.id(),
                "hash-refresh-002",
                BASE_TIME.plusSeconds(1),
                EXPIRES_AT.plusSeconds(1),
                null
        );
        RefreshToken other = createRefreshToken(
                secondUser.id(),
                "hash-refresh-003"
        );

        repository.save(first);
        repository.save(second);
        repository.save(other);

        List<RefreshToken> refreshTokens =
                repository.findByUserId(firstUser.id());

        assertThat(refreshTokens)
                .containsExactly(first, second);
    }

    @Test
    void shouldFindRefreshTokensByUserIdSortedByCreatedAtAndId() {

        User user = saveUser("google-subject-123");
        RefreshToken earliest = createRefreshToken(
                UUID.fromString("00000000-0000-0000-0000-000000000003"),
                user.id(),
                "hash-refresh-earliest",
                BASE_TIME.plusSeconds(1),
                EXPIRES_AT.plusSeconds(1),
                null
        );
        RefreshToken firstById = createRefreshToken(
                UUID.fromString("00000000-0000-0000-0000-000000000001"),
                user.id(),
                "hash-refresh-first-by-id",
                BASE_TIME.plusSeconds(2),
                EXPIRES_AT.plusSeconds(2),
                null
        );
        RefreshToken secondById = createRefreshToken(
                UUID.fromString("00000000-0000-0000-0000-000000000002"),
                user.id(),
                "hash-refresh-second-by-id",
                BASE_TIME.plusSeconds(2),
                EXPIRES_AT.plusSeconds(2),
                null
        );

        repository.save(secondById);
        repository.save(firstById);
        repository.save(earliest);

        List<RefreshToken> refreshTokens =
                repository.findByUserId(user.id());

        assertThat(refreshTokens)
                .extracting(RefreshToken::id)
                .containsExactly(
                        earliest.id(),
                        firstById.id(),
                        secondById.id()
                );
    }

    @Test
    void shouldPreserveNullableRevokedAt() {

        User user = saveUser("google-subject-123");
        RefreshToken refreshToken = createRefreshToken(
                user.id(),
                "hash-refresh-001"
        );

        repository.save(refreshToken);

        RefreshToken loaded = repository.findById(refreshToken.id())
                .orElseThrow();

        assertThat(loaded.revokedAt()).isNull();
    }

    @Test
    void shouldSaveRevokedRefreshToken() {

        User user = saveUser("google-subject-123");
        RefreshToken refreshToken = createRevokedRefreshToken(
                user.id(),
                "hash-refresh-001"
        );

        repository.save(refreshToken);

        RefreshToken loaded = repository.findById(refreshToken.id())
                .orElseThrow();

        assertRefreshTokenMatches(loaded, refreshToken);
    }

    @Test
    void shouldUpdateRevokedAt() {

        User user = saveUser("google-subject-123");
        RefreshToken refreshToken = createRefreshToken(
                user.id(),
                "hash-refresh-001"
        );
        RefreshToken updatedToken = createRefreshToken(
                refreshToken.id(),
                refreshToken.userId(),
                refreshToken.tokenHash(),
                refreshToken.createdAt(),
                refreshToken.expiresAt(),
                BASE_TIME.plusSeconds(60)
        );

        repository.save(refreshToken);

        repository.update(updatedToken);

        RefreshToken loaded = repository.findById(refreshToken.id())
                .orElseThrow();

        assertRefreshTokenMatches(loaded, updatedToken);
    }

    @Test
    void shouldUpdateRevokedAtBackToNull() {

        User user = saveUser("google-subject-123");
        RefreshToken refreshToken = createRevokedRefreshToken(
                user.id(),
                "hash-refresh-001"
        );
        RefreshToken updatedToken = createRefreshToken(
                refreshToken.id(),
                refreshToken.userId(),
                refreshToken.tokenHash(),
                refreshToken.createdAt(),
                refreshToken.expiresAt(),
                null
        );

        repository.save(refreshToken);

        repository.update(updatedToken);

        RefreshToken loaded = repository.findById(refreshToken.id())
                .orElseThrow();

        assertThat(loaded.revokedAt()).isNull();
        assertRefreshTokenMatches(loaded, updatedToken);
    }

    @Test
    void shouldRevokeActiveRefreshToken() {

        User user = saveUser("google-subject-123");
        RefreshToken refreshToken = createRefreshToken(
                user.id(),
                "hash-refresh-001"
        );
        RefreshToken expected = createRefreshToken(
                refreshToken.id(),
                refreshToken.userId(),
                refreshToken.tokenHash(),
                refreshToken.createdAt(),
                refreshToken.expiresAt(),
                REVOKED_AT
        );

        repository.save(refreshToken);

        boolean revoked = repository.revokeIfActive(
                refreshToken.id(),
                REVOKED_AT
        );

        RefreshToken loaded = repository.findById(refreshToken.id())
                .orElseThrow();

        assertThat(revoked).isTrue();
        assertRefreshTokenMatches(loaded, expected);
    }

    @Test
    void shouldReturnFalseWhenRefreshTokenDoesNotExist() {

        boolean revoked = repository.revokeIfActive(
                UUID.randomUUID(),
                REVOKED_AT
        );

        assertThat(revoked).isFalse();
    }

    @Test
    void shouldReturnFalseWhenRefreshTokenIsAlreadyRevoked() {

        User user = saveUser("google-subject-123");
        RefreshToken refreshToken = createRefreshToken(
                UUID.randomUUID(),
                user.id(),
                "hash-refresh-001",
                BASE_TIME,
                EXPIRES_AT,
                FIRST_REVOKED_AT
        );

        repository.save(refreshToken);

        boolean revoked = repository.revokeIfActive(
                refreshToken.id(),
                SECOND_REVOKED_AT
        );

        assertThat(revoked).isFalse();
    }

    @Test
    void shouldPreserveOriginalRevokedAtWhenSecondRevokeFails() {

        User user = saveUser("google-subject-123");
        RefreshToken refreshToken = createRefreshToken(
                user.id(),
                "hash-refresh-001"
        );

        repository.save(refreshToken);

        boolean first = repository.revokeIfActive(
                refreshToken.id(),
                FIRST_REVOKED_AT
        );
        boolean second = repository.revokeIfActive(
                refreshToken.id(),
                SECOND_REVOKED_AT
        );

        RefreshToken loaded = repository.findById(refreshToken.id())
                .orElseThrow();

        assertThat(first).isTrue();
        assertThat(second).isFalse();
        assertThat(loaded.revokedAt()).isEqualTo(FIRST_REVOKED_AT);
    }

    @Test
    void shouldRevokeOnlySpecifiedRefreshToken() {

        User user = saveUser("google-subject-123");
        RefreshToken first = createRefreshToken(
                user.id(),
                "hash-refresh-001"
        );
        RefreshToken second = createRefreshToken(
                user.id(),
                "hash-refresh-002"
        );

        repository.save(first);
        repository.save(second);

        boolean revoked = repository.revokeIfActive(
                first.id(),
                REVOKED_AT
        );

        RefreshToken loadedFirst = repository.findById(first.id())
                .orElseThrow();
        RefreshToken loadedSecond = repository.findById(second.id())
                .orElseThrow();

        assertThat(revoked).isTrue();
        assertThat(loadedFirst.revokedAt()).isEqualTo(REVOKED_AT);
        assertThat(loadedSecond.revokedAt()).isNull();
    }

    @Test
    void shouldAllowOnlyOneConcurrentRevoke() throws Exception {

        User user = saveUser("google-subject-123");
        RefreshToken refreshToken = createRefreshToken(
                user.id(),
                "hash-refresh-001"
        );
        repository.save(refreshToken);

        ExecutorService executor = Executors.newFixedThreadPool(2);
        CountDownLatch ready = new CountDownLatch(2);
        CountDownLatch start = new CountDownLatch(1);

        try {
            Future<RevokeAttemptResult> first = executor.submit(
                    revokeAttempt(
                            refreshToken.id(),
                            FIRST_REVOKED_AT,
                            ready,
                            start
                    )
            );
            Future<RevokeAttemptResult> second = executor.submit(
                    revokeAttempt(
                            refreshToken.id(),
                            SECOND_REVOKED_AT,
                            ready,
                            start
                    )
            );

            assertThat(ready.await(10, TimeUnit.SECONDS)).isTrue();
            start.countDown();

            RevokeAttemptResult firstResult =
                    first.get(10, TimeUnit.SECONDS);
            RevokeAttemptResult secondResult =
                    second.get(10, TimeUnit.SECONDS);

            assertThat(List.of(
                    firstResult.revoked(),
                    secondResult.revoked()
            ))
                    .containsExactlyInAnyOrder(true, false);

            Instant successfulRevokedAt = firstResult.revoked()
                    ? firstResult.revokedAt()
                    : secondResult.revokedAt();
            RefreshToken loaded = repository.findById(refreshToken.id())
                    .orElseThrow();

            assertThat(loaded.revokedAt()).isEqualTo(successfulRevokedAt);
        } finally {
            executor.shutdownNow();
        }
    }

    @Test
    void shouldDeleteRefreshToken() {

        User user = saveUser("google-subject-123");
        RefreshToken first = createRefreshToken(
                user.id(),
                "hash-refresh-001"
        );
        RefreshToken second = createRefreshToken(
                user.id(),
                "hash-refresh-002"
        );

        repository.save(first);
        repository.save(second);

        repository.delete(first.id());

        assertThat(repository.findById(first.id()))
                .isEmpty();

        assertThat(repository.findById(second.id()))
                .contains(second);
    }

    @Test
    void shouldRejectDuplicateRefreshTokenId() {

        User user = saveUser("google-subject-123");
        UUID refreshTokenId = UUID.randomUUID();
        RefreshToken first = createRefreshToken(
                refreshTokenId,
                user.id(),
                "hash-refresh-001",
                BASE_TIME,
                EXPIRES_AT,
                null
        );
        RefreshToken second = createRefreshToken(
                refreshTokenId,
                user.id(),
                "hash-refresh-002",
                BASE_TIME,
                EXPIRES_AT,
                null
        );

        repository.save(first);

        assertThatThrownBy(() -> repository.save(second))
                .isInstanceOf(DuplicateKeyException.class);
    }

    @Test
    void shouldRejectDuplicateTokenHash() {

        User user = saveUser("google-subject-123");
        RefreshToken first = createRefreshToken(
                user.id(),
                "hash-refresh-001"
        );
        RefreshToken second = createRefreshToken(
                user.id(),
                "hash-refresh-001"
        );

        repository.save(first);

        assertThatThrownBy(() -> repository.save(second))
                .isInstanceOf(DuplicateKeyException.class);
    }

    @Test
    void shouldRejectRefreshTokenWithUnknownUser() {

        RefreshToken refreshToken = createRefreshToken(
                UUID.randomUUID(),
                "hash-refresh-001"
        );

        assertThatThrownBy(() -> repository.save(refreshToken))
                .isInstanceOf(DataIntegrityViolationException.class);
    }

    private Callable<RevokeAttemptResult> revokeAttempt(
            UUID refreshTokenId,
            Instant revokedAt,
            CountDownLatch ready,
            CountDownLatch start
    ) {
        return () -> {
            ready.countDown();
            start.await();

            boolean revoked = repository.revokeIfActive(
                    refreshTokenId,
                    revokedAt
            );

            return new RevokeAttemptResult(
                    revoked,
                    revokedAt
            );
        };
    }

    private record RevokeAttemptResult(
            boolean revoked,
            Instant revokedAt
    ) {
    }

}
