package memory_map.backend.auth.refresh;

import memory_map.backend.auth.domain.RefreshToken;
import memory_map.backend.auth.repository.RefreshTokenRepository;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class DefaultRefreshTokenLogoutServiceTest {

    private static final UUID TOKEN_ID =
            UUID.fromString(
                    "00000000-0000-0000-0000-000000000001"
            );
    private static final UUID USER_ID =
            UUID.fromString(
                    "00000000-0000-0000-0000-000000000002"
            );
    private static final Instant CREATED_AT =
            Instant.parse("2026-01-01T10:00:00Z");
    private static final Instant CURRENT_TIME =
            Instant.parse("2026-01-10T10:00:00Z");
    private static final Instant EXPIRES_AT =
            CURRENT_TIME.plusSeconds(60);
    private static final RawRefreshToken RAW_TOKEN =
            new RawRefreshToken(
                    "deterministic-refresh-token"
            );
    private static final String TOKEN_HASH =
            "0123456789abcdef0123456789abcdef"
                    + "0123456789abcdef0123456789abcdef";

    @Test
    void shouldHashRawRefreshToken() {

        TestContext context = testContext();

        context.service().logout(RAW_TOKEN, CURRENT_TIME);

        assertThat(context.hasher().receivedToken()).isSameAs(RAW_TOKEN);
    }

    @Test
    void shouldFindPersistedTokenByHash() {

        TestContext context = testContext();

        context.service().logout(RAW_TOKEN, CURRENT_TIME);

        assertThat(context.repository().receivedTokenHash())
                .isEqualTo(TOKEN_HASH);
    }

    @Test
    void shouldValidatePersistedTokenAtCurrentTime() {

        TestContext context = testContext();

        context.service().logout(RAW_TOKEN, CURRENT_TIME);

        assertThat(context.validator().receivedRefreshToken())
                .isEqualTo(activeToken());
        assertThat(context.validator().receivedCurrentTime())
                .isEqualTo(CURRENT_TIME);
    }

    @Test
    void shouldRevokeActiveRefreshToken() {

        TestContext context = testContext();

        context.service().logout(RAW_TOKEN, CURRENT_TIME);

        assertThat(context.repository().receivedRevokedTokenId())
                .isEqualTo(TOKEN_ID);
        assertThat(context.repository().revokeCalls()).isEqualTo(1);
        assertThat(context.events()).containsExactly(
                "hash",
                "find",
                "validate",
                "revoke"
        );
    }

    @Test
    void shouldUseCurrentTimeAsRevokedAt() {

        TestContext context = testContext();

        context.service().logout(RAW_TOKEN, CURRENT_TIME);

        assertThat(context.repository().receivedRevokedAt())
                .isEqualTo(CURRENT_TIME);
    }

    @Test
    void shouldDoNothingWhenRefreshTokenDoesNotExist() {

        TestContext context = testContext();
        context.repository().findResult(Optional.empty());

        assertThatCode(
                () -> context.service().logout(RAW_TOKEN, CURRENT_TIME)
        ).doesNotThrowAnyException();
        assertThat(context.events()).containsExactly(
                "hash",
                "find"
        );
        assertThat(context.validator().calls()).isZero();
        assertThat(context.repository().revokeCalls()).isZero();
    }

    @Test
    void shouldDoNothingWhenRefreshTokenIsAlreadyRevoked() {

        TestContext context = testContext();
        context.validator().invalidToken();

        assertThatCode(
                () -> context.service().logout(RAW_TOKEN, CURRENT_TIME)
        ).doesNotThrowAnyException();
        assertThat(context.events()).containsExactly(
                "hash",
                "find",
                "validate"
        );
        assertThat(context.repository().revokeCalls()).isZero();
    }

    @Test
    void shouldDoNothingWhenRefreshTokenIsExpired() {

        TestContext context = testContext();
        context.validator().invalidToken();

        assertThatCode(
                () -> context.service().logout(RAW_TOKEN, CURRENT_TIME)
        ).doesNotThrowAnyException();
        assertThat(context.repository().revokeCalls()).isZero();
    }

    @Test
    void shouldDoNothingWhenRefreshTokenExpiresExactlyAtCurrentTime() {

        TestContext context = testContext();
        context.validator().invalidToken();

        assertThatCode(
                () -> context.service().logout(RAW_TOKEN, CURRENT_TIME)
        ).doesNotThrowAnyException();
        assertThat(context.repository().revokeCalls()).isZero();
    }

    @Test
    void shouldCompleteSuccessfullyWhenConditionalRevokeReturnsFalse() {

        TestContext context = testContext();
        context.repository().revokeResult(false);

        assertThatCode(
                () -> context.service().logout(RAW_TOKEN, CURRENT_TIME)
        ).doesNotThrowAnyException();
        assertThat(context.repository().revokeCalls()).isEqualTo(1);
    }

    @Test
    void shouldNotCallRevokeForUnknownToken() {

        TestContext context = testContext();
        context.repository().findResult(Optional.empty());

        context.service().logout(RAW_TOKEN, CURRENT_TIME);

        assertThat(context.repository().revokeCalls()).isZero();
    }

    @Test
    void shouldNotCallRevokeForInvalidPersistedToken() {

        TestContext context = testContext();
        context.validator().invalidToken();

        context.service().logout(RAW_TOKEN, CURRENT_TIME);

        assertThat(context.repository().revokeCalls()).isZero();
    }

    @Test
    void shouldRejectNullRefreshToken() {

        assertThatThrownBy(
                () -> testContext().service().logout(null, CURRENT_TIME)
        )
                .isInstanceOf(NullPointerException.class)
                .hasMessage("refreshToken must not be null");
    }

    @Test
    void shouldRejectNullCurrentTime() {

        assertThatThrownBy(
                () -> testContext().service().logout(RAW_TOKEN, null)
        )
                .isInstanceOf(NullPointerException.class)
                .hasMessage("currentTime must not be null");
    }

    @Test
    void shouldRejectNullHasherDependency() {

        TestContext context = testContext();

        assertThatThrownBy(() -> new DefaultRefreshTokenLogoutService(
                null,
                context.repository(),
                context.validator()
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("refreshTokenHasher must not be null");
    }

    @Test
    void shouldRejectNullRepositoryDependency() {

        TestContext context = testContext();

        assertThatThrownBy(() -> new DefaultRefreshTokenLogoutService(
                context.hasher(),
                null,
                context.validator()
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("refreshTokenRepository must not be null");
    }

    @Test
    void shouldRejectNullValidatorDependency() {

        TestContext context = testContext();

        assertThatThrownBy(() -> new DefaultRefreshTokenLogoutService(
                context.hasher(),
                context.repository(),
                null
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("refreshTokenValidator must not be null");
    }

    private static TestContext testContext() {
        List<String> events = new ArrayList<>();
        FakeRefreshTokenHasher hasher =
                new FakeRefreshTokenHasher(events);
        FakeRefreshTokenRepository repository =
                new FakeRefreshTokenRepository(events);
        FakeRefreshTokenValidator validator =
                new FakeRefreshTokenValidator(events);

        return new TestContext(
                events,
                hasher,
                repository,
                validator,
                new DefaultRefreshTokenLogoutService(
                        hasher,
                        repository,
                        validator
                )
        );
    }

    private static RefreshToken activeToken() {
        return new RefreshToken(
                TOKEN_ID,
                USER_ID,
                TOKEN_HASH,
                CREATED_AT,
                EXPIRES_AT,
                null
        );
    }

    private record TestContext(
            List<String> events,
            FakeRefreshTokenHasher hasher,
            FakeRefreshTokenRepository repository,
            FakeRefreshTokenValidator validator,
            DefaultRefreshTokenLogoutService service
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

            return TOKEN_HASH;
        }

        private RawRefreshToken receivedToken() {
            return receivedToken;
        }
    }

    private static final class FakeRefreshTokenRepository
            implements RefreshTokenRepository {

        private final List<String> events;
        private Optional<RefreshToken> findResult =
                Optional.of(activeToken());
        private boolean revokeResult = true;
        private String receivedTokenHash;
        private UUID receivedRevokedTokenId;
        private Instant receivedRevokedAt;
        private int revokeCalls;

        private FakeRefreshTokenRepository(List<String> events) {
            this.events = events;
        }

        @Override
        public Optional<RefreshToken> findById(UUID id) {
            throw new UnsupportedOperationException();
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
            throw new UnsupportedOperationException();
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
            events.add("revoke");
            revokeCalls++;
            receivedRevokedTokenId = id;
            receivedRevokedAt = revokedAt;

            return revokeResult;
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

        private void findResult(Optional<RefreshToken> findResult) {
            this.findResult = findResult;
        }

        private void revokeResult(boolean revokeResult) {
            this.revokeResult = revokeResult;
        }

        private String receivedTokenHash() {
            return receivedTokenHash;
        }

        private UUID receivedRevokedTokenId() {
            return receivedRevokedTokenId;
        }

        private Instant receivedRevokedAt() {
            return receivedRevokedAt;
        }

        private int revokeCalls() {
            return revokeCalls;
        }
    }

    private static final class FakeRefreshTokenValidator
            implements RefreshTokenValidator {

        private final List<String> events;
        private boolean invalidToken;
        private RefreshToken receivedRefreshToken;
        private Instant receivedCurrentTime;
        private int calls;

        private FakeRefreshTokenValidator(List<String> events) {
            this.events = events;
        }

        @Override
        public void validate(
                RefreshToken refreshToken,
                Instant currentTime
        ) {
            events.add("validate");
            calls++;
            receivedRefreshToken = refreshToken;
            receivedCurrentTime = currentTime;

            if (invalidToken) {
                throw new InvalidRefreshTokenException(
                        "Refresh token is invalid"
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

        private int calls() {
            return calls;
        }
    }
}
