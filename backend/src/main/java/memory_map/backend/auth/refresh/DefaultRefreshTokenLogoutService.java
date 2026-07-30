package memory_map.backend.auth.refresh;

import memory_map.backend.auth.domain.RefreshToken;
import memory_map.backend.auth.repository.RefreshTokenRepository;

import java.time.Instant;
import java.util.Objects;
import java.util.Optional;

public class DefaultRefreshTokenLogoutService
        implements RefreshTokenLogoutService {

    private final RefreshTokenHasher refreshTokenHasher;
    private final RefreshTokenRepository refreshTokenRepository;
    private final RefreshTokenValidator refreshTokenValidator;

    public DefaultRefreshTokenLogoutService(
            RefreshTokenHasher refreshTokenHasher,
            RefreshTokenRepository refreshTokenRepository,
            RefreshTokenValidator refreshTokenValidator
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
    }

    @Override
    public void logout(
            RawRefreshToken refreshToken,
            Instant currentTime
    ) {
        Objects.requireNonNull(
                refreshToken,
                "refreshToken must not be null"
        );
        Objects.requireNonNull(
                currentTime,
                "currentTime must not be null"
        );

        String tokenHash =
                refreshTokenHasher.hash(refreshToken);
        Optional<RefreshToken> foundToken =
                refreshTokenRepository.findByTokenHash(tokenHash);

        if (foundToken.isEmpty()) {
            return;
        }

        RefreshToken persistedToken = foundToken.orElseThrow();

        try {
            refreshTokenValidator.validate(
                    persistedToken,
                    currentTime
            );
        } catch (InvalidRefreshTokenException exception) {
            return;
        }

        refreshTokenRepository.revokeIfActive(
                persistedToken.id(),
                currentTime
        );
    }
}
