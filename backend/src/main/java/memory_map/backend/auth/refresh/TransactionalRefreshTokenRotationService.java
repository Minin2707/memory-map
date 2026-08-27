package memory_map.backend.auth.refresh;

import memory_map.backend.auth.domain.RefreshToken;
import memory_map.backend.auth.jwt.AccessTokenService;
import memory_map.backend.auth.repository.RefreshTokenRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

public class TransactionalRefreshTokenRotationService
        implements RefreshTokenRotationService {

    private static final String INVALID_TOKEN_MESSAGE =
            "Refresh token is invalid";
    private static final Logger LOGGER =
            LoggerFactory.getLogger(
                    TransactionalRefreshTokenRotationService.class
            );

    private final RefreshTokenHasher refreshTokenHasher;
    private final RefreshTokenRepository refreshTokenRepository;
    private final RefreshTokenValidator refreshTokenValidator;
    private final AccessTokenService accessTokenService;
    private final RefreshTokenIssuer refreshTokenIssuer;

    public TransactionalRefreshTokenRotationService(
            RefreshTokenHasher refreshTokenHasher,
            RefreshTokenRepository refreshTokenRepository,
            RefreshTokenValidator refreshTokenValidator,
            AccessTokenService accessTokenService,
            RefreshTokenIssuer refreshTokenIssuer
    ) {
        this.refreshTokenHasher = Objects.requireNonNull(
                refreshTokenHasher,
                "refreshTokenHasher must not be null"
        );
        this.refreshTokenRepository = Objects.requireNonNull(
                refreshTokenRepository,
                "refreshTokenRepository must not be null"
        );
        this.refreshTokenValidator = Objects.requireNonNull(
                refreshTokenValidator,
                "refreshTokenValidator must not be null"
        );
        this.accessTokenService = Objects.requireNonNull(
                accessTokenService,
                "accessTokenService must not be null"
        );
        this.refreshTokenIssuer = Objects.requireNonNull(
                refreshTokenIssuer,
                "refreshTokenIssuer must not be null"
        );
    }

    @Override
    @Transactional(noRollbackFor = InvalidRefreshTokenException.class)
    public RefreshTokenRotationResult rotate(
            RawRefreshToken currentRefreshToken,
            UUID newRefreshTokenId,
            Instant currentTime
    ) {
        Objects.requireNonNull(
                currentRefreshToken,
                "currentRefreshToken must not be null"
        );
        Objects.requireNonNull(
                newRefreshTokenId,
                "newRefreshTokenId must not be null"
        );
        Objects.requireNonNull(
                currentTime,
                "currentTime must not be null"
        );

        String currentTokenHash =
                refreshTokenHasher.hash(currentRefreshToken);
        RefreshToken currentToken =
                refreshTokenRepository
                        .findByTokenHash(currentTokenHash)
                        .orElseThrow(
                                TransactionalRefreshTokenRotationService
                                        ::invalidToken
                        );

        if (currentToken.consumedAt() != null) {
            revokeFamilyForDetectedReuse(
                    currentToken,
                    currentTime
            );
            throw invalidToken();
        }

        refreshTokenValidator.validate(
                currentToken,
                currentTime
        );

        boolean consumed =
                refreshTokenRepository.consumeIfActive(
                        currentToken.id(),
                        currentTime
                );

        if (!consumed) {
            handleFailedConsume(
                    currentToken,
                    currentTime
            );
        }

        String newAccessToken =
                accessTokenService.issueAccessToken(
                        currentToken.userId(),
                        currentTime
                );
        IssuedRefreshToken issuedRefreshToken =
                refreshTokenIssuer.issue(
                        newRefreshTokenId,
                        currentToken.familyId(),
                        currentToken.userId(),
                        currentTime
                );

        refreshTokenRepository.save(
                issuedRefreshToken.refreshToken()
        );

        return new RefreshTokenRotationResult(
                newAccessToken,
                issuedRefreshToken.rawToken()
        );
    }

    private void handleFailedConsume(
            RefreshToken currentToken,
            Instant currentTime
    ) {
        RefreshToken latestToken =
                refreshTokenRepository
                        .findById(currentToken.id())
                        .orElse(currentToken);

        if (latestToken.consumedAt() != null) {
            revokeFamilyForDetectedReuse(
                    latestToken,
                    currentTime
            );
        }

        throw invalidToken();
    }

    private void revokeFamilyForDetectedReuse(
            RefreshToken refreshToken,
            Instant currentTime
    ) {
        refreshTokenRepository.revokeActiveFamily(
                refreshToken.familyId(),
                currentTime
        );
        LOGGER.warn(
                "Refresh token reuse detected; active refresh token family revoked"
        );
    }

    private static InvalidRefreshTokenException invalidToken() {
        return new InvalidRefreshTokenException(
                INVALID_TOKEN_MESSAGE
        );
    }
}
