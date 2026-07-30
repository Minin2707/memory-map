package memory_map.backend.auth.refresh;

import memory_map.backend.IntegrationTest;
import memory_map.backend.auth.domain.RefreshToken;
import memory_map.backend.auth.repository.RefreshTokenRepository;
import memory_map.backend.user.domain.User;
import memory_map.backend.user.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.jdbc.core.simple.JdbcClient;

import java.time.Instant;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class RefreshTokenRotationServiceIntegrationTest extends IntegrationTest {

    @Autowired
    private RefreshTokenRotationService rotationService;

    @Autowired
    private RefreshTokenRepository refreshTokenRepository;

    @Autowired
    private RefreshTokenHasher refreshTokenHasher;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private JdbcClient jdbcClient;

    private static final UUID OLD_TOKEN_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID NEW_TOKEN_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000002");
    private static final UUID DUPLICATE_TOKEN_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000003");
    private static final Instant BASE_TIME =
            Instant.parse("2026-01-01T10:00:00.123456Z");
    private static final Instant CURRENT_TIME =
            Instant.parse("2026-01-10T10:00:00.123456Z");
    private static final Instant EXPIRES_AT =
            Instant.parse("2026-02-01T10:00:00.123456Z");
    private static final RawRefreshToken OLD_RAW_TOKEN =
            new RawRefreshToken("old-refresh-token");
    private static final String CLEAN_DATABASE_SQL = """
        TRUNCATE TABLE users
        RESTART IDENTITY CASCADE
        """;

    @BeforeEach
    void cleanDatabase() {
        jdbcClient.sql(CLEAN_DATABASE_SQL).update();
    }

    @Test
    void shouldRotateRefreshTokenTransactionally() {

        User user = saveUser("google-subject-123");
        RefreshToken oldToken = oldRefreshToken(user.id());
        refreshTokenRepository.save(oldToken);

        RefreshTokenRotationResult result = rotationService.rotate(
                OLD_RAW_TOKEN,
                NEW_TOKEN_ID,
                CURRENT_TIME
        );

        RefreshToken loadedOldToken =
                refreshTokenRepository.findById(OLD_TOKEN_ID)
                        .orElseThrow();
        RefreshToken loadedNewToken =
                refreshTokenRepository.findById(NEW_TOKEN_ID)
                        .orElseThrow();

        assertThat(result.accessToken()).isNotBlank();
        assertThat(result.refreshToken().value())
                .isNotBlank()
                .isNotEqualTo(OLD_RAW_TOKEN.value());
        assertThat(loadedOldToken.revokedAt()).isEqualTo(CURRENT_TIME);
        assertThat(loadedNewToken.userId()).isEqualTo(user.id());
        assertThat(loadedNewToken.createdAt()).isEqualTo(CURRENT_TIME);
        assertThat(loadedNewToken.revokedAt()).isNull();
        assertThat(loadedNewToken.tokenHash())
                .isEqualTo(refreshTokenHasher.hash(result.refreshToken()))
                .isNotEqualTo(result.refreshToken().value());
    }

    @Test
    void shouldRollbackOldTokenRevocationWhenNewTokenSaveFails() {

        User user = saveUser("google-subject-123");
        RefreshToken oldToken = oldRefreshToken(user.id());
        RefreshToken duplicateToken = refreshToken(
                DUPLICATE_TOKEN_ID,
                user.id(),
                "existing-token-hash",
                BASE_TIME.plusSeconds(1),
                EXPIRES_AT.plusSeconds(1),
                null
        );

        refreshTokenRepository.save(oldToken);
        refreshTokenRepository.save(duplicateToken);

        assertThatThrownBy(() -> rotationService.rotate(
                OLD_RAW_TOKEN,
                DUPLICATE_TOKEN_ID,
                CURRENT_TIME
        ))
                .isInstanceOf(DuplicateKeyException.class);

        RefreshToken loadedOldToken =
                refreshTokenRepository.findById(OLD_TOKEN_ID)
                        .orElseThrow();
        RefreshToken loadedDuplicateToken =
                refreshTokenRepository.findById(DUPLICATE_TOKEN_ID)
                        .orElseThrow();

        assertThat(loadedOldToken.revokedAt()).isNull();
        assertThat(loadedDuplicateToken).isEqualTo(duplicateToken);
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

    private RefreshToken oldRefreshToken(UUID userId) {
        return refreshToken(
                OLD_TOKEN_ID,
                userId,
                refreshTokenHasher.hash(OLD_RAW_TOKEN),
                BASE_TIME,
                EXPIRES_AT,
                null
        );
    }

    private static RefreshToken refreshToken(
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
}
