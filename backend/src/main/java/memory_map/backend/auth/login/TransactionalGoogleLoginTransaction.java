package memory_map.backend.auth.login;

import memory_map.backend.auth.domain.GoogleIdentity;
import memory_map.backend.auth.refresh.IssuedRefreshToken;
import memory_map.backend.auth.jwt.AccessTokenService;
import memory_map.backend.auth.refresh.RefreshTokenIssuer;
import memory_map.backend.auth.repository.RefreshTokenRepository;
import memory_map.backend.user.domain.User;
import memory_map.backend.user.repository.UserRepository;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

public class TransactionalGoogleLoginTransaction
        implements GoogleLoginTransaction {

    private static final String DEFAULT_DISPLAY_NAME =
            "Memory Map User";

    private final UserRepository userRepository;
    private final AccessTokenService accessTokenService;
    private final RefreshTokenIssuer refreshTokenIssuer;
    private final RefreshTokenRepository refreshTokenRepository;

    public TransactionalGoogleLoginTransaction(
            UserRepository userRepository,
            AccessTokenService accessTokenService,
            RefreshTokenIssuer refreshTokenIssuer,
            RefreshTokenRepository refreshTokenRepository
    ) {
        this.userRepository = Objects.requireNonNull(
                userRepository,
                "userRepository must not be null"
        );
        this.accessTokenService = Objects.requireNonNull(
                accessTokenService,
                "accessTokenService must not be null"
        );
        this.refreshTokenIssuer = Objects.requireNonNull(
                refreshTokenIssuer,
                "refreshTokenIssuer must not be null"
        );
        this.refreshTokenRepository = Objects.requireNonNull(
                refreshTokenRepository,
                "refreshTokenRepository must not be null"
        );
    }

    @Override
    @Transactional
    public GoogleLoginResult login(
            GoogleIdentity identity,
            UUID newUserId,
            UUID newRefreshTokenId,
            Instant currentTime
    ) {
        Objects.requireNonNull(
                identity,
                "identity must not be null"
        );
        Objects.requireNonNull(
                newUserId,
                "newUserId must not be null"
        );
        Objects.requireNonNull(
                newRefreshTokenId,
                "newRefreshTokenId must not be null"
        );
        Objects.requireNonNull(
                currentTime,
                "currentTime must not be null"
        );

        User user = userRepository
                .findByGoogleSubject(identity.subject())
                .orElseGet(() -> createUser(
                        identity,
                        newUserId,
                        currentTime
                ));

        String accessToken =
                accessTokenService.issueAccessToken(
                        user.id(),
                        currentTime
                );
        IssuedRefreshToken issuedRefreshToken =
                refreshTokenIssuer.issue(
                        newRefreshTokenId,
                        user.id(),
                        currentTime
                );

        refreshTokenRepository.save(
                issuedRefreshToken.refreshToken()
        );

        return new GoogleLoginResult(
                user,
                accessToken,
                issuedRefreshToken.rawToken()
        );
    }

    private User createUser(
            GoogleIdentity identity,
            UUID newUserId,
            Instant currentTime
    ) {
        User user = new User(
                newUserId,
                identity.subject(),
                resolveDisplayName(identity.displayName()),
                identity.avatarUrl(),
                currentTime,
                currentTime
        );

        return userRepository.save(user);
    }

    private static String resolveDisplayName(String displayName) {
        return displayName == null || displayName.isBlank()
                ? DEFAULT_DISPLAY_NAME
                : displayName;
    }
}
