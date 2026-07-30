package memory_map.backend.auth.refresh;

import memory_map.backend.auth.domain.RefreshToken;
import memory_map.backend.auth.jwt.AccessTokenService;
import memory_map.backend.auth.repository.RefreshTokenRepository;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

public class TransactionalRefreshTokenRotationService
        implements RefreshTokenRotationService {

    private static final String INVALID_TOKEN_MESSAGE =
            "Refresh token is invalid";

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
    @Transactional
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

        refreshTokenValidator.validate(
                currentToken,
                currentTime
        );

        String newAccessToken =
                accessTokenService.issueAccessToken(
                        currentToken.userId(),
                        currentTime
                );
        IssuedRefreshToken issuedRefreshToken =
                refreshTokenIssuer.issue(
                        newRefreshTokenId,
                        currentToken.userId(),
                        currentTime
                );

        boolean revoked =
                refreshTokenRepository.revokeIfActive(
                        currentToken.id(),
                        currentTime
                );

        if (!revoked) {
            throw invalidToken();
        }

        refreshTokenRepository.save(
                issuedRefreshToken.refreshToken()
        );

        return new RefreshTokenRotationResult(
                newAccessToken,
                issuedRefreshToken.rawToken()
        );
    }

    private static InvalidRefreshTokenException invalidToken() {
        return new InvalidRefreshTokenException(
                INVALID_TOKEN_MESSAGE
        );
    }
}
