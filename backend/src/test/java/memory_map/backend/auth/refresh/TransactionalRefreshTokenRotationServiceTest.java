package memory_map.backend.auth.refresh;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.auth.domain.RefreshToken;
import memory_map.backend.auth.jwt.AccessTokenService;
import memory_map.backend.auth.repository.RefreshTokenRepository;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class TransactionalRefreshTokenRotationServiceTest {

    private static final String INVALID_TOKEN_MESSAGE =
            "Refresh token is invalid";
    private static final UUID CURRENT_TOKEN_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000002");
    private static final UUID NEW_REFRESH_TOKEN_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000003");
    private static final UUID FAMILY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000004");
    private static final Instant CREATED_AT =
            Instant.parse("2026-01-01T10:00:00Z");
    private static final Instant CURRENT_TIME =
            Instant.parse("2026-01-10T10:00:00Z");
    private static final Instant EXPIRES_AT =
            Instant.parse("2026-02-01T10:00:00Z");
    private static final RawRefreshToken CURRENT_RAW_TOKEN =
            new RawRefreshToken("current-refresh-token");
    private static final String CURRENT_TOKEN_HASH =
            "current-token-hash";
    private static final String NEW_ACCESS_TOKEN =
            "new-access-token";
    private static final RawRefreshToken NEW_RAW_TOKEN =
            new RawRefreshToken("new-refresh-token");
    private static final String NEW_TOKEN_HASH =
            "new-token-hash";

    @Test
    void shouldRotateActiveRefreshToken() {

        TestContext context = testContext();

        RefreshTokenRotationResult result = context.service().rotate(
                CURRENT_RAW_TOKEN,
                NEW_REFRESH_TOKEN_ID,
                CURRENT_TIME
        );

        assertThat(result.accessToken()).isEqualTo(NEW_ACCESS_TOKEN);
        assertThat(result.refreshToken()).isSameAs(NEW_RAW_TOKEN);
        assertThat(context.events()).containsExactly(
                "hash",
                "find",
                "validate",
                "consume",
                "issueAccess",
                "issueRefresh",
                "save"
        );
    }

    @Test
    void shouldHashCurrentRawToken() {

        TestContext context = testContext();

        context.service().rotate(
                CURRENT_RAW_TOKEN,
                NEW_REFRESH_TOKEN_ID,
                CURRENT_TIME
        );

        assertThat(context.hasher().receivedToken())
                .isSameAs(CURRENT_RAW_TOKEN);
    }

    @Test
    void shouldFindPersistedTokenByHash() {

        TestContext context = testContext();

        context.service().rotate(
                CURRENT_RAW_TOKEN,
                NEW_REFRESH_TOKEN_ID,
                CURRENT_TIME
        );

        assertThat(context.repository().receivedTokenHash())
                .isEqualTo(CURRENT_TOKEN_HASH);
    }

    @Test
    void shouldValidatePersistedTokenAtCurrentTime() {

        TestContext context = testContext();

        context.service().rotate(
                CURRENT_RAW_TOKEN,
                NEW_REFRESH_TOKEN_ID,
                CURRENT_TIME
        );

        assertThat(context.validator().receivedRefreshToken())
                .isEqualTo(currentRefreshToken());
        assertThat(context.validator().receivedCurrentTime())
                .isEqualTo(CURRENT_TIME);
    }

    @Test
    void shouldIssueAccessTokenForPersistedUser() {

        TestContext context = testContext();

        context.service().rotate(
                CURRENT_RAW_TOKEN,
                NEW_REFRESH_TOKEN_ID,
                CURRENT_TIME
        );

        assertThat(context.accessTokenService().receivedUserId())
                .isEqualTo(USER_ID);
        assertThat(context.accessTokenService().receivedIssuedAt())
                .isEqualTo(CURRENT_TIME);
    }

    @Test
    void shouldIssueNewRefreshTokenForPersistedUser() {

        TestContext context = testContext();

        context.service().rotate(
                CURRENT_RAW_TOKEN,
                NEW_REFRESH_TOKEN_ID,
                CURRENT_TIME
        );

        assertThat(context.refreshTokenIssuer().receivedTokenId())
                .isEqualTo(NEW_REFRESH_TOKEN_ID);
        assertThat(context.refreshTokenIssuer().receivedUserId())
                .isEqualTo(USER_ID);
        assertThat(context.refreshTokenIssuer().receivedIssuedAt())
                .isEqualTo(CURRENT_TIME);
    }

    @Test
    void shouldConsumeCurrentTokenBeforeSavingNewToken() {

        TestContext context = testContext();

        context.service().rotate(
                CURRENT_RAW_TOKEN,
                NEW_REFRESH_TOKEN_ID,
                CURRENT_TIME
        );

        assertThat(context.events()).containsSubsequence(
                "consume",
                "save"
        );
        assertThat(context.repository().receivedConsumedTokenId())
                .isEqualTo(CURRENT_TOKEN_ID);
        assertThat(context.repository().receivedConsumedAt())
                .isEqualTo(CURRENT_TIME);
    }

    @Test
    void shouldSaveNewPersistedRefreshToken() {

        TestContext context = testContext();

        context.service().rotate(
                CURRENT_RAW_TOKEN,
                NEW_REFRESH_TOKEN_ID,
                CURRENT_TIME
        );

        assertThat(context.repository().savedRefreshToken())
                .isEqualTo(newRefreshToken());
    }

    @Test
    void shouldIssueRotatedRefreshTokenInSameFamily() {

        TestContext context = testContext();

        context.service().rotate(
                CURRENT_RAW_TOKEN,
                NEW_REFRESH_TOKEN_ID,
                CURRENT_TIME
        );

        assertThat(context.refreshTokenIssuer().receivedFamilyId())
                .isEqualTo(FAMILY_ID);
        assertThat(context.repository().savedRefreshToken().familyId())
                .isEqualTo(FAMILY_ID);
    }

    @Test
    void shouldReturnNewAccessAndRawRefreshTokens() {

        TestContext context = testContext();

        RefreshTokenRotationResult result = context.service().rotate(
                CURRENT_RAW_TOKEN,
                NEW_REFRESH_TOKEN_ID,
                CURRENT_TIME
        );

        assertThat(result.accessToken()).isEqualTo(NEW_ACCESS_TOKEN);
        assertThat(result.refreshToken()).isSameAs(NEW_RAW_TOKEN);
    }

    @Test
    void shouldRejectUnknownRefreshToken() {

        TestContext context = testContext();
        context.repository().findResult(Optional.empty());

        assertInvalidToken(() -> context.service().rotate(
                CURRENT_RAW_TOKEN,
                NEW_REFRESH_TOKEN_ID,
                CURRENT_TIME
        ));
        assertThat(context.events()).containsExactly(
                "hash",
                "find"
        );
        assertThat(context.validator().called()).isFalse();
        assertThat(context.accessTokenService().called()).isFalse();
        assertThat(context.refreshTokenIssuer().called()).isFalse();
        assertThat(context.repository().consumeCalled()).isFalse();
        assertThat(context.repository().revokeFamilyCalled()).isFalse();
        assertThat(context.repository().saveCalled()).isFalse();
    }

    @Test
    void shouldRejectInvalidPersistedTokenWithoutFamilyRevocation() {

        TestContext context = testContext();
        context.validator().invalidToken();

        assertInvalidToken(() -> context.service().rotate(
                CURRENT_RAW_TOKEN,
                NEW_REFRESH_TOKEN_ID,
                CURRENT_TIME
        ));

        assertThat(context.events()).containsExactly(
                "hash",
                "find",
                "validate"
        );
        assertThat(context.repository().consumeCalled()).isFalse();
        assertThat(context.repository().revokeFamilyCalled()).isFalse();
        assertThat(context.accessTokenService().called()).isFalse();
        assertThat(context.refreshTokenIssuer().called()).isFalse();
        assertThat(context.repository().saveCalled()).isFalse();
    }

    @Test
    void shouldRejectConcurrentReplayWhenConditionalConsumeReturnsFalse() {

        TestContext context = testContext();
        context.repository().consumeResult(false);
        context.repository().findByIdResult(Optional.of(consumedRefreshToken()));

        assertInvalidToken(() -> context.service().rotate(
                CURRENT_RAW_TOKEN,
                NEW_REFRESH_TOKEN_ID,
                CURRENT_TIME
        ));

        assertThat(context.repository().receivedRevokedFamilyId())
                .isEqualTo(FAMILY_ID);
    }

    @Test
    void shouldNotSaveNewTokenWhenConditionalConsumeFails() {

        TestContext context = testContext();
        context.repository().consumeResult(false);
        context.repository().findByIdResult(Optional.of(consumedRefreshToken()));

        assertInvalidToken(() -> context.service().rotate(
                CURRENT_RAW_TOKEN,
                NEW_REFRESH_TOKEN_ID,
                CURRENT_TIME
        ));

        assertThat(context.refreshTokenIssuer().called()).isFalse();
        assertThat(context.repository().saveCalled()).isFalse();
    }

    @Test
    void shouldRevokeActiveFamilyWhenConsumedTokenIsReused() {

        TestContext context = testContext();
        context.repository().findResult(Optional.of(consumedRefreshToken()));

        assertInvalidToken(() -> context.service().rotate(
                CURRENT_RAW_TOKEN,
                NEW_REFRESH_TOKEN_ID,
                CURRENT_TIME
        ));

        assertThat(context.events()).containsExactly(
                "hash",
                "find",
                "revokeFamily"
        );
        assertThat(context.repository().receivedRevokedFamilyId())
                .isEqualTo(FAMILY_ID);
        assertThat(context.repository().receivedRevokedAt())
                .isEqualTo(CURRENT_TIME);
        assertThat(context.validator().called()).isFalse();
        assertThat(context.accessTokenService().called()).isFalse();
        assertThat(context.refreshTokenIssuer().called()).isFalse();
        assertThat(context.repository().saveCalled()).isFalse();
    }

    @Test
    void shouldRejectNullCurrentRefreshToken() {

        assertThatThrownBy(() -> testContext().service().rotate(
                null,
                NEW_REFRESH_TOKEN_ID,
                CURRENT_TIME
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("currentRefreshToken must not be null");
    }

    @Test
    void shouldRejectNullNewRefreshTokenId() {

        assertThatThrownBy(() -> testContext().service().rotate(
                CURRENT_RAW_TOKEN,
                null,
                CURRENT_TIME
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("newRefreshTokenId must not be null");
    }

    @Test
    void shouldRejectNullCurrentTime() {

        assertThatThrownBy(() -> testContext().service().rotate(
                CURRENT_RAW_TOKEN,
                NEW_REFRESH_TOKEN_ID,
                null
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("currentTime must not be null");
    }

    @Test
    void shouldRejectNullHasherDependency() {

        TestContext context = testContext();

        assertThatThrownBy(() -> new TransactionalRefreshTokenRotationService(
                null,
                context.repository(),
                context.validator(),
                context.accessTokenService(),
                context.refreshTokenIssuer()
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("refreshTokenHasher must not be null");
    }

    @Test
    void shouldRejectNullRepositoryDependency() {

        TestContext context = testContext();

        assertThatThrownBy(() -> new TransactionalRefreshTokenRotationService(
                context.hasher(),
                null,
                context.validator(),
                context.accessTokenService(),
                context.refreshTokenIssuer()
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("refreshTokenRepository must not be null");
    }

    @Test
    void shouldRejectNullValidatorDependency() {

        TestContext context = testContext();

        assertThatThrownBy(() -> new TransactionalRefreshTokenRotationService(
                context.hasher(),
                context.repository(),
                null,
                context.accessTokenService(),
                context.refreshTokenIssuer()
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("refreshTokenValidator must not be null");
    }

    @Test
    void shouldRejectNullAccessTokenServiceDependency() {

        TestContext context = testContext();

        assertThatThrownBy(() -> new TransactionalRefreshTokenRotationService(
                context.hasher(),
                context.repository(),
                context.validator(),
                null,
                context.refreshTokenIssuer()
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("accessTokenService must not be null");
    }

    @Test
    void shouldRejectNullRefreshTokenIssuerDependency() {

        TestContext context = testContext();

        assertThatThrownBy(() -> new TransactionalRefreshTokenRotationService(
                context.hasher(),
                context.repository(),
                context.validator(),
                context.accessTokenService(),
                null
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("refreshTokenIssuer must not be null");
    }

    private static TestContext testContext() {
        List<String> events = new ArrayList<>();
        FakeRefreshTokenHasher hasher =
                new FakeRefreshTokenHasher(events);
        FakeRefreshTokenRepository repository =
                new FakeRefreshTokenRepository(events);
        FakeRefreshTokenValidator validator =
                new FakeRefreshTokenValidator(events);
        FakeAccessTokenService accessTokenService =
                new FakeAccessTokenService(events);
        FakeRefreshTokenIssuer refreshTokenIssuer =
                new FakeRefreshTokenIssuer(events);

        return new TestContext(
                events,
                hasher,
                repository,
                validator,
                accessTokenService,
                refreshTokenIssuer,
                new TransactionalRefreshTokenRotationService(
                        hasher,
                        repository,
                        validator,
                        accessTokenService,
                        refreshTokenIssuer
                )
        );
    }

    private static RefreshToken currentRefreshToken() {
        return new RefreshToken(
                CURRENT_TOKEN_ID,
                USER_ID,
                FAMILY_ID,
                CURRENT_TOKEN_HASH,
                CREATED_AT,
                EXPIRES_AT,
                null,
                null
        );
    }

    private static RefreshToken consumedRefreshToken() {
        return new RefreshToken(
                CURRENT_TOKEN_ID,
                USER_ID,
                FAMILY_ID,
                CURRENT_TOKEN_HASH,
                CREATED_AT,
                EXPIRES_AT,
                CURRENT_TIME.minusSeconds(1),
                null
        );
    }

    private static RefreshToken newRefreshToken() {
        return new RefreshToken(
                NEW_REFRESH_TOKEN_ID,
                USER_ID,
                FAMILY_ID,
                NEW_TOKEN_HASH,
                CURRENT_TIME,
                CURRENT_TIME.plusSeconds(30L * 24 * 60 * 60),
                null,
                null
        );
    }

    private static IssuedRefreshToken issuedRefreshToken() {
        return new IssuedRefreshToken(
                NEW_RAW_TOKEN,
                newRefreshToken()
        );
    }

    private static void assertInvalidToken(ThrowingAction action) {
        assertThatThrownBy(action::run)
                .isInstanceOf(InvalidRefreshTokenException.class)
                .hasMessage(INVALID_TOKEN_MESSAGE);
    }

    private record TestContext(
            List<String> events,
            FakeRefreshTokenHasher hasher,
            FakeRefreshTokenRepository repository,
            FakeRefreshTokenValidator validator,
            FakeAccessTokenService accessTokenService,
            FakeRefreshTokenIssuer refreshTokenIssuer,
            TransactionalRefreshTokenRotationService service
    ) {
    }

    private static final class FakeRefreshTokenHasher
            implements RefreshTokenHasher {

        private final List<String> events;
        private RawRefreshToken receivedToken;

        private FakeRefreshTokenHasher(List<String> events) {
            this.events = events;
        }

        @Override
        public String hash(RawRefreshToken rawToken) {
            events.add("hash");
            receivedToken = rawToken;

            return CURRENT_TOKEN_HASH;
        }

        private RawRefreshToken receivedToken() {
            return receivedToken;
        }
    }

    private static final class FakeRefreshTokenRepository
            implements RefreshTokenRepository {

        private final List<String> events;
        private Optional<RefreshToken> findResult =
                Optional.of(currentRefreshToken());
        private Optional<RefreshToken> findByIdResult =
                Optional.of(currentRefreshToken());
        private boolean consumeResult = true;
        private String receivedTokenHash;
        private UUID receivedConsumedTokenId;
        private Instant receivedConsumedAt;
        private UUID receivedRevokedFamilyId;
        private Instant receivedRevokedAt;
        private RefreshToken savedRefreshToken;
        private boolean consumeCalled;
        private boolean revokeFamilyCalled;
        private boolean saveCalled;

        private FakeRefreshTokenRepository(List<String> events) {
            this.events = events;
        }

        @Override
        public Optional<RefreshToken> findById(UUID id) {
            events.add("findById");

            return findByIdResult;
        }

        @Override
        public Optional<RefreshToken> findByTokenHash(String tokenHash) {
            events.add("find");
            receivedTokenHash = tokenHash;

            return findResult;
        }

        @Override
        public List<RefreshToken> findByUserId(UUID userId) {
            throw new UnsupportedOperationException();
        }

        @Override
        public void save(RefreshToken refreshToken) {
            events.add("save");
            saveCalled = true;
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
            events.add("consume");
            consumeCalled = true;
            receivedConsumedTokenId = id;
            receivedConsumedAt = consumedAt;

            return consumeResult;
        }

        @Override
        public int revokeActiveFamily(
                UUID familyId,
                Instant revokedAt
        ) {
            events.add("revokeFamily");
            revokeFamilyCalled = true;
            receivedRevokedFamilyId = familyId;
            receivedRevokedAt = revokedAt;

            return 1;
        }

        @Override
        public void delete(UUID id) {
            throw new UnsupportedOperationException();
        }

        private void findResult(Optional<RefreshToken> findResult) {
            this.findResult = findResult;
        }

        private void consumeResult(boolean consumeResult) {
            this.consumeResult = consumeResult;
        }

        private void findByIdResult(Optional<RefreshToken> findByIdResult) {
            this.findByIdResult = findByIdResult;
        }

        private String receivedTokenHash() {
            return receivedTokenHash;
        }

        private UUID receivedConsumedTokenId() {
            return receivedConsumedTokenId;
        }

        private Instant receivedConsumedAt() {
            return receivedConsumedAt;
        }

        private UUID receivedRevokedFamilyId() {
            return receivedRevokedFamilyId;
        }

        private Instant receivedRevokedAt() {
            return receivedRevokedAt;
        }

        private RefreshToken savedRefreshToken() {
            return savedRefreshToken;
        }

        private boolean consumeCalled() {
            return consumeCalled;
        }

        private boolean revokeFamilyCalled() {
            return revokeFamilyCalled;
        }

        private boolean saveCalled() {
            return saveCalled;
        }
    }

    private static final class FakeRefreshTokenValidator
            implements RefreshTokenValidator {

        private final List<String> events;
        private RefreshToken receivedRefreshToken;
        private Instant receivedCurrentTime;
        private boolean invalidToken;
        private boolean called;

        private FakeRefreshTokenValidator(List<String> events) {
            this.events = events;
        }

        @Override
        public void validate(
                RefreshToken refreshToken,
                Instant currentTime
        ) {
            events.add("validate");
            called = true;
            receivedRefreshToken = refreshToken;
            receivedCurrentTime = currentTime;

            if (invalidToken) {
                throw new InvalidRefreshTokenException(
                        INVALID_TOKEN_MESSAGE
                );
            }
        }

        private void invalidToken() {
            invalidToken = true;
        }

        private RefreshToken receivedRefreshToken() {
            return receivedRefreshToken;
        }

        private Instant receivedCurrentTime() {
            return receivedCurrentTime;
        }

        private boolean called() {
            return called;
        }
    }

    private static final class FakeAccessTokenService
            implements AccessTokenService {

        private final List<String> events;
        private UUID receivedUserId;
        private Instant receivedIssuedAt;
        private boolean called;

        private FakeAccessTokenService(List<String> events) {
            this.events = events;
        }

        @Override
        public String issueAccessToken(
                UUID userId,
                Instant issuedAt
        ) {
            events.add("issueAccess");
            called = true;
            receivedUserId = userId;
            receivedIssuedAt = issuedAt;

            return NEW_ACCESS_TOKEN;
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

        private boolean called() {
            return called;
        }
    }

    private static final class FakeRefreshTokenIssuer
            implements RefreshTokenIssuer {

        private final List<String> events;
        private UUID receivedTokenId;
        private UUID receivedFamilyId;
        private UUID receivedUserId;
        private Instant receivedIssuedAt;
        private boolean called;

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
            called = true;
            receivedTokenId = tokenId;
            receivedFamilyId = familyId;
            receivedUserId = userId;
            receivedIssuedAt = issuedAt;

            return issuedRefreshToken();
        }

        private UUID receivedTokenId() {
            return receivedTokenId;
        }

        private UUID receivedFamilyId() {
            return receivedFamilyId;
        }

        private UUID receivedUserId() {
            return receivedUserId;
        }

        private Instant receivedIssuedAt() {
            return receivedIssuedAt;
        }

        private boolean called() {
            return called;
        }
    }

    @FunctionalInterface
    private interface ThrowingAction {

        void run();

    }
}
