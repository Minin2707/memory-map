package memory_map.backend.auth.jwt;

import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.oauth2.core.DelegatingOAuth2TokenValidator;
import org.springframework.security.oauth2.core.OAuth2TokenValidator;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtIssuerValidator;
import org.springframework.security.oauth2.jwt.JwtTimestampValidator;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;
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
    public JwtDecoder jwtDecoder(
            SecretKey jwtSecretKey,
            JwtAuthProperties properties
    ) {
        NimbusJwtDecoder jwtDecoder = NimbusJwtDecoder
                .withSecretKey(jwtSecretKey)
                .macAlgorithm(MacAlgorithm.HS256)
                .build();

        JwtTimestampValidator timestampValidator =
                new JwtTimestampValidator();
        timestampValidator.setAllowEmptyExpiryClaim(false);

        OAuth2TokenValidator<Jwt> validator =
                new DelegatingOAuth2TokenValidator<>(
                        timestampValidator,
                        new JwtIssuerValidator(properties.issuer()),
                        new JwtIssuedAtValidator()
                );

        jwtDecoder.setJwtValidator(validator);

        return jwtDecoder;
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

    @Bean
    public AccessTokenVerifier accessTokenVerifier(
            JwtDecoder jwtDecoder
    ) {
        return new NimbusAccessTokenVerifier(jwtDecoder);
    }

    @Bean
    public AccessTokenService accessTokenService(
            AccessTokenIssuer accessTokenIssuer,
            AccessTokenVerifier accessTokenVerifier
    ) {
        return new DefaultAccessTokenService(
                accessTokenIssuer,
                accessTokenVerifier
        );
    }
}
