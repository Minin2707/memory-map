package memory_map.backend.auth.login;

import memory_map.backend.IntegrationTest;
import memory_map.backend.auth.domain.GoogleIdentity;
import memory_map.backend.auth.domain.RefreshToken;
import memory_map.backend.auth.google.GoogleIdentityVerificationException;
import memory_map.backend.auth.google.GoogleIdentityVerifier;
import memory_map.backend.auth.refresh.RefreshTokenHasher;
import memory_map.backend.auth.repository.RefreshTokenRepository;
import memory_map.backend.user.domain.User;
import memory_map.backend.user.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.context.annotation.Primary;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.jdbc.core.simple.JdbcClient;

import java.time.Instant;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

@Import(GoogleLoginServiceIntegrationTest.GoogleLoginTestConfiguration.class)
class GoogleLoginServiceIntegrationTest extends IntegrationTest {

    @Autowired
    private GoogleLoginService loginService;

    @Autowired
    private FakeGoogleIdentityVerifier googleIdentityVerifier;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private RefreshTokenRepository refreshTokenRepository;

    @Autowired
    private RefreshTokenHasher refreshTokenHasher;

    @Autowired
    private JdbcClient jdbcClient;

    private static final String GOOGLE_ID_TOKEN =
            "raw-google-id-token";
    private static final String GOOGLE_SUBJECT =
            "google-subject-123";
    private static final UUID NEW_USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID EXISTING_USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000002");
    private static final UUID NEW_REFRESH_TOKEN_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000003");
    private static final UUID SECOND_NEW_USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000004");
    private static final UUID SECOND_REFRESH_TOKEN_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000005");
    private static final Instant BASE_TIME =
            Instant.parse("2026-01-01T10:00:00.123456Z");
    private static final Instant UPDATED_AT =
            Instant.parse("2026-01-02T10:00:00.123456Z");
    private static final Instant CURRENT_TIME =
            Instant.parse("2026-01-10T10:00:00.123456Z");
    private static final Instant EXPIRES_AT =
            Instant.parse("2026-02-01T10:00:00.123456Z");
    private static final String CLEAN_DATABASE_SQL = """
        TRUNCATE TABLE users
        RESTART IDENTITY CASCADE
        """;

    @BeforeEach
    void cleanDatabase() {
        jdbcClient.sql(CLEAN_DATABASE_SQL).update();
        googleIdentityVerifier.identity(
                googleIdentity()
        );
    }

    @Test
    void shouldCreateUserAndSessionForFirstGoogleLogin() {

        GoogleLoginResult result = loginService.login(
                GOOGLE_ID_TOKEN,
                NEW_USER_ID,
                NEW_REFRESH_TOKEN_ID,
                CURRENT_TIME
        );

        User persistedUser = userRepository
                .findById(NEW_USER_ID)
                .orElseThrow();
        RefreshToken persistedRefreshToken = refreshTokenRepository
                .findById(NEW_REFRESH_TOKEN_ID)
                .orElseThrow();

        assertThat(googleIdentityVerifier.receivedGoogleIdToken())
                .isEqualTo(GOOGLE_ID_TOKEN);
        assertThat(persistedUser.googleSubject())
                .isEqualTo(GOOGLE_SUBJECT);
        assertThat(persistedUser.displayName())
                .isEqualTo("Konstantin");
        assertThat(persistedUser.displayNameCustomized()).isFalse();
        assertThat(persistedUser.avatarUrl())
                .isEqualTo("https://example.com/avatar.png");
        assertThat(persistedUser.createdAt())
                .isEqualTo(CURRENT_TIME);
        assertThat(persistedUser.updatedAt())
                .isEqualTo(CURRENT_TIME);
        assertThat(result.user()).isEqualTo(persistedUser);
        assertThat(result.accessToken()).isNotBlank();
        assertThat(result.refreshToken().value()).isNotBlank();
        assertThat(persistedRefreshToken.userId())
                .isEqualTo(persistedUser.id());
        assertThat(persistedRefreshToken.familyId())
                .isEqualTo(persistedRefreshToken.id());
        assertThat(persistedRefreshToken.consumedAt()).isNull();
        assertThat(persistedRefreshToken.tokenHash())
                .isEqualTo(refreshTokenHasher.hash(result.refreshToken()))
                .isNotEqualTo(result.refreshToken().value());
        assertThat(persistedRefreshToken.createdAt())
                .isEqualTo(CURRENT_TIME);
        assertThat(persistedRefreshToken.revokedAt()).isNull();
    }

    @Test
    void shouldReuseExistingUserForSubsequentGoogleLogin() {

        User existingUser = saveUser(
                EXISTING_USER_ID,
                GOOGLE_SUBJECT,
                "Persisted Name",
                "https://example.com/persisted.png",
                BASE_TIME,
                UPDATED_AT
        );
        googleIdentityVerifier.identity(
                new GoogleIdentity(
                        GOOGLE_SUBJECT,
                        "New Google Name",
                        "https://example.com/new.png"
                )
        );

        GoogleLoginResult result = loginService.login(
                GOOGLE_ID_TOKEN,
                NEW_USER_ID,
                NEW_REFRESH_TOKEN_ID,
                CURRENT_TIME
        );

        User loadedExistingUser = userRepository
                .findById(EXISTING_USER_ID)
                .orElseThrow();
        RefreshToken persistedRefreshToken = refreshTokenRepository
                .findById(NEW_REFRESH_TOKEN_ID)
                .orElseThrow();

        assertThat(userRepository.findById(NEW_USER_ID)).isEmpty();
        assertThat(result.user()).isEqualTo(loadedExistingUser);
        assertThat(loadedExistingUser.id()).isEqualTo(existingUser.id());
        assertThat(loadedExistingUser.googleSubject())
                .isEqualTo(existingUser.googleSubject());
        assertThat(loadedExistingUser.displayName())
                .isEqualTo("New Google Name");
        assertThat(loadedExistingUser.displayNameCustomized()).isFalse();
        assertThat(loadedExistingUser.avatarUrl())
                .isEqualTo("https://example.com/new.png");
        assertThat(loadedExistingUser.customAvatarStorageKey()).isNull();
        assertThat(loadedExistingUser.customAvatarUpdatedAt()).isNull();
        assertThat(loadedExistingUser.createdAt())
                .isEqualTo(existingUser.createdAt());
        assertThat(loadedExistingUser.updatedAt()).isEqualTo(CURRENT_TIME);
        assertThat(persistedRefreshToken.userId())
                .isEqualTo(EXISTING_USER_ID);
    }

    @Test
    void shouldPreserveCustomizedDisplayNameForSubsequentGoogleLogin() {

        User existingUser = saveUser(
                EXISTING_USER_ID,
                GOOGLE_SUBJECT,
                "George",
                "https://example.com/persisted.png",
                BASE_TIME,
                UPDATED_AT
        );
        userRepository.updateDisplayName(
                existingUser.id(),
                "Georgy B.",
                UPDATED_AT.plusSeconds(1)
        );
        googleIdentityVerifier.identity(
                new GoogleIdentity(
                        GOOGLE_SUBJECT,
                        "George Belyavsky",
                        "https://example.com/new.png"
                )
        );

        GoogleLoginResult result = loginService.login(
                GOOGLE_ID_TOKEN,
                NEW_USER_ID,
                NEW_REFRESH_TOKEN_ID,
                CURRENT_TIME
        );

        User loadedExistingUser = userRepository
                .findById(EXISTING_USER_ID)
                .orElseThrow();

        assertThat(result.user()).isEqualTo(loadedExistingUser);
        assertThat(loadedExistingUser.displayName()).isEqualTo("Georgy B.");
        assertThat(loadedExistingUser.displayNameCustomized()).isTrue();
        assertThat(loadedExistingUser.avatarUrl())
                .isEqualTo("https://example.com/new.png");
    }

    @Test
    void shouldCreateNewUserWhenPreviousGoogleSubjectWasTombstoned() {

        User deletedUser = saveUser(
                EXISTING_USER_ID,
                GOOGLE_SUBJECT,
                "Deleted User",
                null,
                BASE_TIME,
                UPDATED_AT
        );
        userRepository.tombstoneById(deletedUser.id(), CURRENT_TIME);

        GoogleLoginResult result = loginService.login(
                GOOGLE_ID_TOKEN,
                NEW_USER_ID,
                NEW_REFRESH_TOKEN_ID,
                CURRENT_TIME
        );

        User oldTombstone = userRepository.findById(deletedUser.id())
                .orElseThrow();
        User newUser = userRepository.findById(NEW_USER_ID)
                .orElseThrow();

        assertThat(oldTombstone.googleSubject()).isNull();
        assertThat(oldTombstone.deletedAt()).isEqualTo(CURRENT_TIME);
        assertThat(result.user()).isEqualTo(newUser);
        assertThat(newUser.id()).isEqualTo(NEW_USER_ID);
        assertThat(newUser.googleSubject()).isEqualTo(GOOGLE_SUBJECT);
        assertThat(newUser.displayName()).isEqualTo("Konstantin");
        assertThat(newUser.displayNameCustomized()).isFalse();
        assertThat(refreshTokenRepository.findById(NEW_REFRESH_TOKEN_ID)
                .orElseThrow()
                .userId())
                .isEqualTo(NEW_USER_ID);
    }

    @Test
    void shouldUseFallbackDisplayNameWhenGoogleNameIsMissing() {

        googleIdentityVerifier.identity(
                new GoogleIdentity(
                        GOOGLE_SUBJECT,
                        null,
                        "https://example.com/avatar.png"
                )
        );

        loginService.login(
                GOOGLE_ID_TOKEN,
                NEW_USER_ID,
                NEW_REFRESH_TOKEN_ID,
                CURRENT_TIME
        );

        User persistedUser = userRepository
                .findById(NEW_USER_ID)
                .orElseThrow();

        assertThat(persistedUser.displayName())
                .isEqualTo("Memory Map User");
    }

    @Test
    void shouldRollbackNewUserWhenRefreshTokenPersistenceFails() {

        User tokenOwner = saveUser(
                EXISTING_USER_ID,
                "existing-google-subject",
                "Existing User",
                null,
                BASE_TIME,
                BASE_TIME
        );
        RefreshToken duplicateRefreshToken = new RefreshToken(
                NEW_REFRESH_TOKEN_ID,
                tokenOwner.id(),
                "existing-refresh-token-hash",
                BASE_TIME,
                EXPIRES_AT,
                null
        );
        refreshTokenRepository.save(duplicateRefreshToken);
        googleIdentityVerifier.identity(
                new GoogleIdentity(
                        "rollback-google-subject",
                        "Rollback User",
                        null
                )
        );

        assertThatThrownBy(() -> loginService.login(
                GOOGLE_ID_TOKEN,
                NEW_USER_ID,
                NEW_REFRESH_TOKEN_ID,
                CURRENT_TIME
        ))
                .isInstanceOf(DuplicateKeyException.class);

        assertThat(userRepository.findById(NEW_USER_ID)).isEmpty();
        assertThat(userRepository.findByGoogleSubject(
                "rollback-google-subject"
        )).isEmpty();
        assertThat(refreshTokenRepository.findById(NEW_REFRESH_TOKEN_ID))
                .contains(duplicateRefreshToken);
    }

    @Test
    void shouldCompleteConcurrentFirstLoginWithSinglePersistedUser()
            throws Exception {

        ExecutorService executor = Executors.newFixedThreadPool(2);
        CountDownLatch startLatch = new CountDownLatch(1);

        try {
            Future<GoogleLoginResult> firstLogin = executor.submit(() -> {
                startLatch.await();

                return loginService.login(
                        GOOGLE_ID_TOKEN,
                        NEW_USER_ID,
                        NEW_REFRESH_TOKEN_ID,
                        CURRENT_TIME
                );
            });
            Future<GoogleLoginResult> secondLogin = executor.submit(() -> {
                startLatch.await();

                return loginService.login(
                        GOOGLE_ID_TOKEN,
                        SECOND_NEW_USER_ID,
                        SECOND_REFRESH_TOKEN_ID,
                        CURRENT_TIME
                );
            });

            startLatch.countDown();

            GoogleLoginResult firstResult =
                    firstLogin.get(10, TimeUnit.SECONDS);
            GoogleLoginResult secondResult =
                    secondLogin.get(10, TimeUnit.SECONDS);

            User persistedUser = userRepository
                    .findByGoogleSubject(GOOGLE_SUBJECT)
                    .orElseThrow();
            RefreshToken firstRefreshToken = refreshTokenRepository
                    .findById(NEW_REFRESH_TOKEN_ID)
                    .orElseThrow();
            RefreshToken secondRefreshToken = refreshTokenRepository
                    .findById(SECOND_REFRESH_TOKEN_ID)
                    .orElseThrow();

            assertThat(firstResult.user().id())
                    .isEqualTo(persistedUser.id());
            assertThat(secondResult.user().id())
                    .isEqualTo(persistedUser.id());
            assertThat(userCountByGoogleSubject(GOOGLE_SUBJECT))
                    .isEqualTo(1);
            assertThat(refreshTokenCountByUserId(persistedUser.id()))
                    .isEqualTo(2);
            assertThat(firstRefreshToken.userId())
                    .isEqualTo(persistedUser.id());
            assertThat(secondRefreshToken.userId())
                    .isEqualTo(persistedUser.id());
            assertThat(firstRefreshToken.familyId())
                    .isEqualTo(firstRefreshToken.id());
            assertThat(secondRefreshToken.familyId())
                    .isEqualTo(secondRefreshToken.id());
            assertThat(firstRefreshToken.revokedAt()).isNull();
            assertThat(secondRefreshToken.revokedAt()).isNull();
            assertThat(firstResult.accessToken()).isNotBlank();
            assertThat(secondResult.accessToken()).isNotBlank();
            assertThat(firstResult.refreshToken().value()).isNotBlank();
            assertThat(secondResult.refreshToken().value()).isNotBlank();
            assertThat(firstResult.refreshToken().value())
                    .isNotEqualTo(secondResult.refreshToken().value());
            assertThat(firstRefreshToken.tokenHash())
                    .isEqualTo(refreshTokenHasher.hash(
                            firstResult.refreshToken()
                    ))
                    .isNotEqualTo(firstResult.refreshToken().value());
            assertThat(secondRefreshToken.tokenHash())
                    .isEqualTo(refreshTokenHasher.hash(
                            secondResult.refreshToken()
                    ))
                    .isNotEqualTo(secondResult.refreshToken().value());
        } finally {
            executor.shutdownNow();
        }
    }

    private User saveUser(
            UUID id,
            String googleSubject,
            String displayName,
            String avatarUrl,
            Instant createdAt,
            Instant updatedAt
    ) {
        return userRepository.save(
                new User(
                        id,
                        googleSubject,
                        displayName,
                        avatarUrl,
                        createdAt,
                        updatedAt
                )
        );
    }

    private static GoogleIdentity googleIdentity() {
        return new GoogleIdentity(
                GOOGLE_SUBJECT,
                "Konstantin",
                "https://example.com/avatar.png"
        );
    }

    private int userCountByGoogleSubject(String googleSubject) {
        return jdbcClient.sql("""
                SELECT COUNT(*)
                FROM users
                WHERE google_subject = :googleSubject
                """)
                .param("googleSubject", googleSubject)
                .query(Integer.class)
                .single();
    }

    private int refreshTokenCountByUserId(UUID userId) {
        return jdbcClient.sql("""
                SELECT COUNT(*)
                FROM refresh_tokens
                WHERE user_id = :userId
                """)
                .param("userId", userId)
                .query(Integer.class)
                .single();
    }

    @TestConfiguration(proxyBeanMethods = false)
    static class GoogleLoginTestConfiguration {

        @Bean
        @Primary
        FakeGoogleIdentityVerifier fakeGoogleIdentityVerifier() {
            return new FakeGoogleIdentityVerifier();
        }
    }

    static final class FakeGoogleIdentityVerifier
            implements GoogleIdentityVerifier {

        private volatile GoogleIdentity identity = googleIdentity();
        private volatile String receivedGoogleIdToken;

        @Override
        public GoogleIdentity verify(String idToken) {
            receivedGoogleIdToken = idToken;

            if (!GOOGLE_ID_TOKEN.equals(idToken)) {
                throw new GoogleIdentityVerificationException(
                        "Google ID token verification failed"
                );
            }

            return identity;
        }

        private void identity(GoogleIdentity identity) {
            this.identity = identity;
        }

        private String receivedGoogleIdToken() {
            return receivedGoogleIdToken;
        }
    }
}
