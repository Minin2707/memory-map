package memory_map.backend.auth.jwt;

import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Bean;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.NimbusJwtEncoder;

import javax.crypto.SecretKey;

@Configuration
@EnableConfigurationProperties(JwtAuthProperties.class)
public class JwtAccessTokenConfiguration {

    @Bean
    public SecretKey jwtSecretKey(JwtAuthProperties properties) {

        return JwtSecretKeyFactory.create(properties.secretBase64());
    }

    @Bean
    public JwtEncoder jwtEncoder(SecretKey jwtSecretKey) {

        return NimbusJwtEncoder
                .withSecretKey(jwtSecretKey)
                .algorithm(MacAlgorithm.HS256)
                .build();
    }

    @Bean
    public AccessTokenIssuer accessTokenIssuer(
            JwtEncoder jwtEncoder,
            JwtAuthProperties properties
    ) {
        return new NimbusAccessTokenIssuer(
                jwtEncoder,
                properties
        );
    }
}
