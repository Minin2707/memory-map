package memory_map.backend.auth.refresh;

import memory_map.backend.IntegrationTest;
import memory_map.backend.auth.domain.RefreshToken;
import memory_map.backend.auth.repository.RefreshTokenRepository;
import memory_map.backend.user.domain.User;
import memory_map.backend.user.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.simple.JdbcClient;

import java.time.Instant;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;

class RefreshTokenLogoutServiceIntegrationTest extends IntegrationTest {

    @Autowired
    private RefreshTokenLogoutService logoutService;

    @Autowired
    private RefreshTokenRepository refreshTokenRepository;

    @Autowired
    private RefreshTokenHasher refreshTokenHasher;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private JdbcClient jdbcClient;

    private static final UUID FIRST_TOKEN_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID SECOND_TOKEN_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000002");
    private static final Instant BASE_TIME =
            Instant.parse("2026-01-01T10:00:00.123456Z");
    private static final Instant CURRENT_TIME =
            Instant.parse("2026-01-10T10:00:00.123456Z");
    private static final Instant EXPIRES_AT =
            Instant.parse("2026-02-01T10:00:00.123456Z");
    private static final Instant EXPIRED_AT =
            Instant.parse("2026-01-09T10:00:00.123456Z");
    private static final Instant REVOKED_AT =
            Instant.parse("2026-01-05T10:00:00.123456Z");
    private static final RawRefreshToken RAW_TOKEN =
            new RawRefreshToken(
                    "integration-refresh-token"
            );
    private static final String CLEAN_DATABASE_SQL = """
        TRUNCATE TABLE users
        RESTART IDENTITY CASCADE
        """;

    @BeforeEach
    void cleanDatabase() {
        jdbcClient.sql(CLEAN_DATABASE_SQL).update();
    }

    @Test
    void shouldLogoutActiveRefreshToken() {

        User user = saveUser("google-subject-123");
        RefreshToken refreshToken = refreshToken(
                FIRST_TOKEN_ID,
                user.id(),
                refreshTokenHasher.hash(RAW_TOKEN),
                EXPIRES_AT,
                null
        );
        refreshTokenRepository.save(refreshToken);

        logoutService.logout(RAW_TOKEN, CURRENT_TIME);

        RefreshToken loaded = refreshTokenRepository
                .findById(FIRST_TOKEN_ID)
                .orElseThrow();

        assertThat(loaded.id()).isEqualTo(refreshToken.id());
        assertThat(loaded.userId()).isEqualTo(refreshToken.userId());
        assertThat(loaded.tokenHash()).isEqualTo(refreshToken.tokenHash());
        assertThat(loaded.createdAt()).isEqualTo(refreshToken.createdAt());
        assertThat(loaded.expiresAt()).isEqualTo(refreshToken.expiresAt());
        assertThat(loaded.consumedAt()).isNull();
        assertThat(loaded.revokedAt()).isEqualTo(CURRENT_TIME);
    }

    @Test
    void shouldCompleteWhenRefreshTokenDoesNotExist() {

        assertThatCode(
                () -> logoutService.logout(RAW_TOKEN, CURRENT_TIME)
        ).doesNotThrowAnyException();
    }

    @Test
    void shouldCompleteWhenRefreshTokenIsAlreadyRevoked() {

        User user = saveUser("google-subject-123");
        RefreshToken refreshToken = refreshToken(
                FIRST_TOKEN_ID,
                user.id(),
                refreshTokenHasher.hash(RAW_TOKEN),
                EXPIRES_AT,
                REVOKED_AT
        );
        refreshTokenRepository.save(refreshToken);

        assertThatCode(
                () -> logoutService.logout(RAW_TOKEN, CURRENT_TIME)
        ).doesNotThrowAnyException();

        RefreshToken loaded = refreshTokenRepository
                .findById(FIRST_TOKEN_ID)
                .orElseThrow();

        assertThat(loaded.revokedAt()).isEqualTo(REVOKED_AT);
    }

    @Test
    void shouldCompleteWhenRefreshTokenIsExpired() {

        User user = saveUser("google-subject-123");
        RefreshToken refreshToken = refreshToken(
                FIRST_TOKEN_ID,
                user.id(),
                refreshTokenHasher.hash(RAW_TOKEN),
                EXPIRED_AT,
                null
        );
        refreshTokenRepository.save(refreshToken);

        assertThatCode(
                () -> logoutService.logout(RAW_TOKEN, CURRENT_TIME)
        ).doesNotThrowAnyException();
    }

    @Test
    void shouldNotRevokeExpiredRefreshToken() {

        User user = saveUser("google-subject-123");
        RefreshToken refreshToken = refreshToken(
                FIRST_TOKEN_ID,
                user.id(),
                refreshTokenHasher.hash(RAW_TOKEN),
                EXPIRED_AT,
                null
        );
        refreshTokenRepository.save(refreshToken);

        logoutService.logout(RAW_TOKEN, CURRENT_TIME);

        RefreshToken loaded = refreshTokenRepository
                .findById(FIRST_TOKEN_ID)
                .orElseThrow();

        assertThat(loaded.revokedAt()).isNull();
    }

    @Test
    void shouldNotAffectOtherRefreshTokens() {

        User user = saveUser("google-subject-123");
        RawRefreshToken otherRawToken =
                new RawRefreshToken("other-refresh-token");
        RefreshToken first = refreshToken(
                FIRST_TOKEN_ID,
                user.id(),
                refreshTokenHasher.hash(RAW_TOKEN),
                EXPIRES_AT,
                null
        );
        RefreshToken second = refreshToken(
                SECOND_TOKEN_ID,
                user.id(),
                refreshTokenHasher.hash(otherRawToken),
                EXPIRES_AT,
                null
        );

        refreshTokenRepository.save(first);
        refreshTokenRepository.save(second);

        logoutService.logout(RAW_TOKEN, CURRENT_TIME);

        RefreshToken loadedFirst = refreshTokenRepository
                .findById(FIRST_TOKEN_ID)
                .orElseThrow();
        RefreshToken loadedSecond = refreshTokenRepository
                .findById(SECOND_TOKEN_ID)
                .orElseThrow();

        assertThat(loadedFirst.revokedAt()).isEqualTo(CURRENT_TIME);
        assertThat(loadedSecond.revokedAt()).isNull();
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

    private static RefreshToken refreshToken(
            UUID id,
            UUID userId,
            String tokenHash,
            Instant expiresAt,
            Instant revokedAt
    ) {
        return new RefreshToken(
                id,
                userId,
                tokenHash,
                BASE_TIME,
                expiresAt,
                revokedAt
        );
    }
}
