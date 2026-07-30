package memory_map.backend.auth.login;

import memory_map.backend.auth.google.GoogleIdentityVerifier;
import memory_map.backend.auth.jwt.AccessTokenService;
import memory_map.backend.auth.refresh.RefreshTokenIssuer;
import memory_map.backend.auth.repository.RefreshTokenRepository;
import memory_map.backend.user.repository.UserRepository;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class GoogleLoginConfiguration {

    @Bean
    public GoogleLoginTransaction googleLoginTransaction(
            UserRepository userRepository,
            AccessTokenService accessTokenService,
            RefreshTokenIssuer refreshTokenIssuer,
            RefreshTokenRepository refreshTokenRepository
    ) {
        return new TransactionalGoogleLoginTransaction(
                userRepository,
                accessTokenService,
                refreshTokenIssuer,
                refreshTokenRepository
        );
    }

    @Bean
    public GoogleLoginService googleLoginService(
            GoogleIdentityVerifier googleIdentityVerifier,
            GoogleLoginTransaction googleLoginTransaction
    ) {
        return new DefaultGoogleLoginService(
                googleIdentityVerifier,
                googleLoginTransaction
        );
    }
}
