package memory_map.backend.auth.refresh;

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
}
