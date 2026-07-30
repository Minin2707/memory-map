package memory_map.backend.auth.refresh;

import memory_map.backend.auth.jwt.AccessTokenService;
import memory_map.backend.auth.repository.RefreshTokenRepository;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.security.SecureRandom;

@Configuration
@EnableConfigurationProperties(
        RefreshTokenProperties.class
)
public class RefreshTokenConfiguration {

    @Bean
    public SecureRandom refreshTokenSecureRandom() {
        return new SecureRandom();
    }

    @Bean
    public RawRefreshTokenGenerator rawRefreshTokenGenerator(
            SecureRandom refreshTokenSecureRandom
    ) {
        return new SecureRandomRawRefreshTokenGenerator(
                refreshTokenSecureRandom
        );
    }

    @Bean
    public RefreshTokenHasher refreshTokenHasher() {
        return new Sha256RefreshTokenHasher();
    }

    @Bean
    public RefreshTokenIssuer refreshTokenIssuer(
            RawRefreshTokenGenerator rawTokenGenerator,
            RefreshTokenHasher refreshTokenHasher,
            RefreshTokenProperties properties
    ) {
        return new DefaultRefreshTokenIssuer(
                rawTokenGenerator,
                refreshTokenHasher,
                properties
        );
    }

    @Bean
    public RefreshTokenValidator refreshTokenValidator() {
        return new DefaultRefreshTokenValidator();
    }

    @Bean
    public RefreshTokenRotationService refreshTokenRotationService(
            RefreshTokenHasher refreshTokenHasher,
            RefreshTokenRepository refreshTokenRepository,
            RefreshTokenValidator refreshTokenValidator,
            AccessTokenService accessTokenService,
            RefreshTokenIssuer refreshTokenIssuer
    ) {
        return new TransactionalRefreshTokenRotationService(
                refreshTokenHasher,
                refreshTokenRepository,
                refreshTokenValidator,
                accessTokenService,
                refreshTokenIssuer
        );
    }

    @Bean
    public RefreshTokenLogoutService refreshTokenLogoutService(
            RefreshTokenHasher refreshTokenHasher,
            RefreshTokenRepository refreshTokenRepository,
            RefreshTokenValidator refreshTokenValidator
    ) {
        return new DefaultRefreshTokenLogoutService(
                refreshTokenHasher,
                refreshTokenRepository,
                refreshTokenValidator
        );
    }
}
