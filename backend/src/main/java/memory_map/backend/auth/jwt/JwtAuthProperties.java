package memory_map.backend.auth.jwt;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

import java.time.Duration;

@ConfigurationProperties(prefix = "app.auth.jwt")
@Validated
public record JwtAuthProperties(

        @NotBlank String issuer,

        @NotNull Duration accessTokenTtl,

        @NotBlank String secretBase64

) {
    public JwtAuthProperties {
        if (
                accessTokenTtl != null
                        && (accessTokenTtl.isZero()
                        || accessTokenTtl.isNegative())
        ) {
            throw new IllegalArgumentException(
                    "accessTokenTtl must be positive"
            );
        }
    }
}
