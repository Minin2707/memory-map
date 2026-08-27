package memory_map.backend.auth.login;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.auth.domain.GoogleIdentity;
import memory_map.backend.auth.domain.RefreshToken;
import memory_map.backend.auth.jwt.AccessTokenService;
import memory_map.backend.auth.refresh.IssuedRefreshToken;
import memory_map.backend.auth.refresh.RawRefreshToken;
import memory_map.backend.auth.refresh.RefreshTokenIssuer;
import memory_map.backend.auth.repository.RefreshTokenRepository;
import memory_map.backend.user.domain.User;
import memory_map.backend.user.repository.UserRepository;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class TransactionalGoogleLoginTransactionTest {

    private static final UUID NEW_USER_ID =
            UUID.fromString(
                    "00000000-0000-0000-0000-000000000001"
            );
    private static final UUID EXISTING_USER_ID =
            UUID.fromString(
                    "00000000-0000-0000-0000-000000000002"
            );
    private static final UUID NEW_REFRESH_TOKEN_ID =
            UUID.fromString(
                    "00000000-0000-0000-0000-000000000003"
            );
    private static final Instant CREATED_AT =
            Instant.parse("2026-01-01T10:00:00Z");
    private static final Instant UPDATED_AT =
            Instant.parse("2026-01-02T10:00:00Z");
    private static final Instant CURRENT_TIME =
            Instant.parse("2026-01-10T10:00:00Z");
    private static final String ACCESS_TOKEN =
            "issued-access-token";
    private static final String TOKEN_HASH =
            "0123456789abcdef0123456789abcdef"
                    + "0123456789abcdef0123456789abcdef";
    private static final RawRefreshToken RAW_REFRESH_TOKEN =
            new RawRefreshToken("raw-refresh-token");
    private static final GoogleIdentity IDENTITY =
            new GoogleIdentity(
                    "google-subject-123",
                    "Konstantin",
                    "https://example.com/avatar.png"
            );
    private static final User EXISTING_USER =
            new User(
                    EXISTING_USER_ID,
                    "google-subject-123",
                    "Persisted Name",
                    "https://example.com/persisted.png",
                    CREATED_AT,
                    UPDATED_AT
            );

    @Test
    void shouldUseExistingUser() {

        TestContext context = testContextWithExistingUser();

        GoogleLoginResult result = context.transaction().login(
                IDENTITY,
                NEW_USER_ID,
                NEW_REFRESH_TOKEN_ID,
                CURRENT_TIME
        );

        assertThat(result.user()).isEqualTo(EXISTING_USER);
    }

    @Test
    void shouldNotSaveExistingUser() {

        TestContext context = testContextWithExistingUser();

        context.transaction().login(
                IDENTITY,
                NEW_USER_ID,
                NEW_REFRESH_TOKEN_ID,
                CURRENT_TIME
        );

        assertThat(context.userRepository().saveCalls()).isZero();
    }

    @Test
    void shouldNotUpdateExistingUserProfile() {

        TestContext context = testContextWithExistingUser();

        GoogleLoginResult result = context.transaction().login(
                new GoogleIdentity(
                        "google-subject-123",
                        "New Google Name",
                        "https://example.com/new.png"
                ),
                NEW_USER_ID,
                NEW_REFRESH_TOKEN_ID,
                CURRENT_TIME
        );

        assertThat(result.user()).isEqualTo(EXISTING_USER);
        assertThat(context.userRepository().saveCalls()).isZero();
    }

    @Test
    void shouldIssueAccessTokenForExistingUser() {

        TestContext context = testContextWithExistingUser();

        context.transaction().login(
                IDENTITY,
                NEW_USER_ID,
                NEW_REFRESH_TOKEN_ID,
                CURRENT_TIME
        );

        assertThat(context.accessTokenService().receivedUserId())
                .isEqualTo(EXISTING_USER_ID);
        assertThat(context.accessTokenService().receivedIssuedAt())
                .isEqualTo(CURRENT_TIME);
    }

    @Test
    void shouldIssueRefreshTokenForExistingUser() {

        TestContext context = testContextWithExistingUser();

        context.transaction().login(
                IDENTITY,
                NEW_USER_ID,
                NEW_REFRESH_TOKEN_ID,
                CURRENT_TIME
        );

        assertThat(context.refreshTokenIssuer().receivedTokenId())
                .isEqualTo(NEW_REFRESH_TOKEN_ID);
        assertThat(context.refreshTokenIssuer().receivedUserId())
                .isEqualTo(EXISTING_USER_ID);
        assertThat(context.refreshTokenIssuer().receivedIssuedAt())
                .isEqualTo(CURRENT_TIME);
    }

    @Test
    void shouldSavePersistedRefreshTokenForExistingUser() {

        TestContext context = testContextWithExistingUser();

        context.transaction().login(
                IDENTITY,
                NEW_USER_ID,
                NEW_REFRESH_TOKEN_ID,
                CURRENT_TIME
        );

        assertThat(context.refreshTokenRepository().savedRefreshToken())
                .isEqualTo(refreshToken(EXISTING_USER_ID));
    }

    @Test
    void shouldReturnExistingUserAndIssuedTokens() {

        TestContext context = testContextWithExistingUser();

        GoogleLoginResult result = context.transaction().login(
                IDENTITY,
                NEW_USER_ID,
                NEW_REFRESH_TOKEN_ID,
                CURRENT_TIME
        );

        assertThat(result).isEqualTo(new GoogleLoginResult(
                EXISTING_USER,
                ACCESS_TOKEN,
                RAW_REFRESH_TOKEN
        ));
    }

    @Test
    void shouldCreateUserWhenGoogleSubjectDoesNotExist() {

        TestContext context = testContext();

        context.transaction().login(
                IDENTITY,
                NEW_USER_ID,
                NEW_REFRESH_TOKEN_ID,
                CURRENT_TIME
        );

        assertThat(context.userRepository().savedUser())
                .isEqualTo(createdUser(IDENTITY));
    }

    @Test
    void shouldUseProvidedNewUserId() {

        TestContext context = testContext();

        context.transaction().login(
                IDENTITY,
                NEW_USER_ID,
                NEW_REFRESH_TOKEN_ID,
                CURRENT_TIME
        );

        assertThat(context.userRepository().savedUser().id())
                .isEqualTo(NEW_USER_ID);
    }

    @Test
    void shouldUseGoogleSubject() {

        TestContext context = testContext();

        context.transaction().login(
                IDENTITY,
                NEW_USER_ID,
                NEW_REFRESH_TOKEN_ID,
                CURRENT_TIME
        );

        assertThat(context.userRepository().savedUser().googleSubject())
                .isEqualTo(IDENTITY.subject());
    }

    @Test
    void shouldUseGoogleDisplayName() {

        TestContext context = testContext();

        context.transaction().login(
                IDENTITY,
                NEW_USER_ID,
                NEW_REFRESH_TOKEN_ID,
                CURRENT_TIME
        );

        assertThat(context.userRepository().savedUser().displayName())
                .isEqualTo(IDENTITY.displayName());
    }

    @Test
    void shouldUseGoogleAvatarUrl() {

        TestContext context = testContext();

        context.transaction().login(
                IDENTITY,
                NEW_USER_ID,
                NEW_REFRESH_TOKEN_ID,
                CURRENT_TIME
        );

        assertThat(context.userRepository().savedUser().avatarUrl())
                .isEqualTo(IDENTITY.avatarUrl());
    }

    @Test
    void shouldSetCreatedAtAndUpdatedAtFromCurrentTime() {

        TestContext context = testContext();

        context.transaction().login(
                IDENTITY,
                NEW_USER_ID,
                NEW_REFRESH_TOKEN_ID,
                CURRENT_TIME
        );

        assertThat(context.userRepository().savedUser().createdAt())
                .isEqualTo(CURRENT_TIME);
        assertThat(context.userRepository().savedUser().updatedAt())
                .isEqualTo(CURRENT_TIME);
    }

    @Test
    void shouldUseDefaultDisplayNameWhenGoogleNameIsNull() {

        TestContext context = testContext();

        context.transaction().login(
                new GoogleIdentity(
                        "google-subject-123",
                        null,
                        "https://example.com/avatar.png"
                ),
                NEW_USER_ID,
                NEW_REFRESH_TOKEN_ID,
                CURRENT_TIME
        );

        assertThat(context.userRepository().savedUser().displayName())
                .isEqualTo("Memory Map User");
    }

    @Test
    void shouldUseDefaultDisplayNameWhenGoogleNameIsBlank() {

        TestContext context = testContext();

        context.transaction().login(
                new GoogleIdentity(
                        "google-subject-123",
                        "   ",
                        "https://example.com/avatar.png"
                ),
                NEW_USER_ID,
                NEW_REFRESH_TOKEN_ID,
                CURRENT_TIME
        );

        assertThat(context.userRepository().savedUser().displayName())
                .isEqualTo("Memory Map User");
    }

    @Test
    void shouldIssueTokensForCreatedUser() {

        TestContext context = testContext();

        context.transaction().login(
                IDENTITY,
                NEW_USER_ID,
                NEW_REFRESH_TOKEN_ID,
                CURRENT_TIME
        );

        assertThat(context.accessTokenService().receivedUserId())
                .isEqualTo(NEW_USER_ID);
        assertThat(context.refreshTokenIssuer().receivedUserId())
                .isEqualTo(NEW_USER_ID);
    }

    @Test
    void shouldSavePersistedRefreshTokenForCreatedUser() {

        TestContext context = testContext();

        context.transaction().login(
                IDENTITY,
                NEW_USER_ID,
                NEW_REFRESH_TOKEN_ID,
                CURRENT_TIME
        );

        assertThat(context.refreshTokenRepository().savedRefreshToken())
                .isEqualTo(refreshToken(NEW_USER_ID));
    }

    @Test
    void shouldCallDependenciesInOrderForNewUser() {

        TestContext context = testContext();

        context.transaction().login(
                IDENTITY,
                NEW_USER_ID,
                NEW_REFRESH_TOKEN_ID,
                CURRENT_TIME
        );

        assertThat(context.events()).containsExactly(
                "findUser",
                "saveUser",
                "issueAccess",
                "issueRefresh",
                "saveRefresh"
        );
    }

    @Test
    void shouldCallDependenciesInOrderForExistingUser() {

        TestContext context = testContextWithExistingUser();

        context.transaction().login(
                IDENTITY,
                NEW_USER_ID,
                NEW_REFRESH_TOKEN_ID,
                CURRENT_TIME
        );

        assertThat(context.events()).containsExactly(
                "findUser",
                "issueAccess",
                "issueRefresh",
                "saveRefresh"
        );
    }

    @Test
    void shouldRejectNullIdentity() {

        assertThatThrownBy(() -> testContext().transaction().login(
                null,
                NEW_USER_ID,
                NEW_REFRESH_TOKEN_ID,
                CURRENT_TIME
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("identity must not be null");
    }

    @Test
    void shouldRejectNullNewUserId() {

        assertThatThrownBy(() -> testContext().transaction().login(
                IDENTITY,
                null,
                NEW_REFRESH_TOKEN_ID,
                CURRENT_TIME
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("newUserId must not be null");
    }

    @Test
    void shouldRejectNullNewRefreshTokenId() {

        assertThatThrownBy(() -> testContext().transaction().login(
                IDENTITY,
                NEW_USER_ID,
                null,
                CURRENT_TIME
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("newRefreshTokenId must not be null");
    }

    @Test
    void shouldRejectNullCurrentTime() {

        assertThatThrownBy(() -> testContext().transaction().login(
                IDENTITY,
                NEW_USER_ID,
                NEW_REFRESH_TOKEN_ID,
                null
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("currentTime must not be null");
    }

    @Test
    void shouldRejectNullUserRepositoryDependency() {

        TestContext context = testContext();

        assertThatThrownBy(() -> new TransactionalGoogleLoginTransaction(
                null,
                context.accessTokenService(),
                context.refreshTokenIssuer(),
                context.refreshTokenRepository()
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("userRepository must not be null");
    }

    @Test
    void shouldRejectNullAccessTokenServiceDependency() {

        TestContext context = testContext();

        assertThatThrownBy(() -> new TransactionalGoogleLoginTransaction(
                context.userRepository(),
                null,
                context.refreshTokenIssuer(),
                context.refreshTokenRepository()
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("accessTokenService must not be null");
    }

    @Test
    void shouldRejectNullRefreshTokenIssuerDependency() {

        TestContext context = testContext();

        assertThatThrownBy(() -> new TransactionalGoogleLoginTransaction(
                context.userRepository(),
                context.accessTokenService(),
                null,
                context.refreshTokenRepository()
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("refreshTokenIssuer must not be null");
    }

    @Test
    void shouldRejectNullRefreshTokenRepositoryDependency() {

        TestContext context = testContext();

        assertThatThrownBy(() -> new TransactionalGoogleLoginTransaction(
                context.userRepository(),
                context.accessTokenService(),
                context.refreshTokenIssuer(),
                null
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("refreshTokenRepository must not be null");
    }

    private static TestContext testContext() {
        List<String> events = new ArrayList<>();
        FakeUserRepository userRepository =
                new FakeUserRepository(events);
        FakeAccessTokenService accessTokenService =
                new FakeAccessTokenService(events);
        FakeRefreshTokenIssuer refreshTokenIssuer =
                new FakeRefreshTokenIssuer(events);
        FakeRefreshTokenRepository refreshTokenRepository =
                new FakeRefreshTokenRepository(events);

        return new TestContext(
                events,
                userRepository,
                accessTokenService,
                refreshTokenIssuer,
                refreshTokenRepository,
                new TransactionalGoogleLoginTransaction(
                        userRepository,
                        accessTokenService,
                        refreshTokenIssuer,
                        refreshTokenRepository
                )
        );
    }

    private static TestContext testContextWithExistingUser() {
        TestContext context = testContext();
        context.userRepository().findResult(
                Optional.of(EXISTING_USER)
        );

        return context;
    }

    private static User createdUser(GoogleIdentity identity) {
        return new User(
                NEW_USER_ID,
                identity.subject(),
                identity.displayName(),
                identity.avatarUrl(),
                CURRENT_TIME,
                CURRENT_TIME
        );
    }

    private static RefreshToken refreshToken(UUID userId) {
        return new RefreshToken(
                NEW_REFRESH_TOKEN_ID,
                userId,
                TOKEN_HASH,
                CURRENT_TIME,
                CURRENT_TIME.plusSeconds(60),
                null
        );
    }

    private record TestContext(
            List<String> events,
            FakeUserRepository userRepository,
            FakeAccessTokenService accessTokenService,
            FakeRefreshTokenIssuer refreshTokenIssuer,
            FakeRefreshTokenRepository refreshTokenRepository,
            TransactionalGoogleLoginTransaction transaction
    ) {
    }

    private static final class FakeUserRepository
            implements UserRepository {

        private final List<String> events;
        private Optional<User> findResult = Optional.empty();
        private User savedUser;
        private int saveCalls;

        private FakeUserRepository(List<String> events) {
            this.events = events;
        }

        @Override
        public User save(User user) {
            events.add("saveUser");
            saveCalls++;
            savedUser = user;

            return user;
        }

        @Override
        public Optional<User> findById(UUID id) {
            throw new UnsupportedOperationException();
        }

        @Override
        public Optional<User> findByGoogleSubject(String googleSubject) {
            events.add("findUser");

            return findResult;
        }

        private void findResult(Optional<User> findResult) {
            this.findResult = findResult;
        }

        private User savedUser() {
            return savedUser;
        }

        private int saveCalls() {
            return saveCalls;
        }
    }

    private static final class FakeAccessTokenService
            implements AccessTokenService {

        private final List<String> events;
        private UUID receivedUserId;
        private Instant receivedIssuedAt;

        private FakeAccessTokenService(List<String> events) {
            this.events = events;
        }

        @Override
        public String issueAccessToken(
                UUID userId,
                Instant issuedAt
        ) {
            events.add("issueAccess");
            receivedUserId = userId;
            receivedIssuedAt = issuedAt;

            return ACCESS_TOKEN;
        }

        @Override
        public AuthenticatedUser verifyAccessToken(String accessToken) {
            throw new UnsupportedOperationException();
        }

        private UUID receivedUserId() {
            return receivedUserId;
        }

        private Instant receivedIssuedAt() {
            return receivedIssuedAt;
        }
    }

    private static final class FakeRefreshTokenIssuer
            implements RefreshTokenIssuer {

        private final List<String> events;
        private UUID receivedTokenId;
        private UUID receivedUserId;
        private Instant receivedIssuedAt;

        private FakeRefreshTokenIssuer(List<String> events) {
            this.events = events;
        }

        @Override
        public IssuedRefreshToken issue(
                UUID tokenId,
                UUID familyId,
                UUID userId,
                Instant issuedAt
        ) {
            events.add("issueRefresh");
            receivedTokenId = tokenId;
            receivedUserId = userId;
            receivedIssuedAt = issuedAt;

            return new IssuedRefreshToken(
                    RAW_REFRESH_TOKEN,
                    refreshToken(userId)
            );
        }

        private UUID receivedTokenId() {
            return receivedTokenId;
        }

        private UUID receivedUserId() {
            return receivedUserId;
        }

        private Instant receivedIssuedAt() {
            return receivedIssuedAt;
        }
    }

    private static final class FakeRefreshTokenRepository
            implements RefreshTokenRepository {

        private final List<String> events;
        private RefreshToken savedRefreshToken;

        private FakeRefreshTokenRepository(List<String> events) {
            this.events = events;
        }

        @Override
        public Optional<RefreshToken> findById(UUID id) {
            throw new UnsupportedOperationException();
        }

        @Override
        public Optional<RefreshToken> findByTokenHash(String tokenHash) {
            throw new UnsupportedOperationException();
        }

        @Override
        public List<RefreshToken> findByUserId(UUID userId) {
            throw new UnsupportedOperationException();
        }

        @Override
        public void save(RefreshToken refreshToken) {
            events.add("saveRefresh");
            savedRefreshToken = refreshToken;
        }

        @Override
        public void update(RefreshToken refreshToken) {
            throw new UnsupportedOperationException();
        }

        @Override
        public boolean revokeIfActive(
                UUID id,
                Instant revokedAt
        ) {
            throw new UnsupportedOperationException();
        }

        @Override
        public boolean consumeIfActive(
                UUID id,
                Instant consumedAt
        ) {
            throw new UnsupportedOperationException();
        }

        @Override
        public int revokeActiveFamily(
                UUID familyId,
                Instant revokedAt
        ) {
            throw new UnsupportedOperationException();
        }

        @Override
        public void delete(UUID id) {
            throw new UnsupportedOperationException();
        }

        private RefreshToken savedRefreshToken() {
            return savedRefreshToken;
        }
    }
}
