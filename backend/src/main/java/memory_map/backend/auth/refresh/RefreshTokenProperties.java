package memory_map.backend.auth.refresh;

import jakarta.validation.constraints.NotNull;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

import java.time.Duration;

@ConfigurationProperties(
        prefix = "app.auth.refresh-token"
)
@Validated
public record RefreshTokenProperties(

        @NotNull Duration ttl

) {
    public RefreshTokenProperties {
        if (
                ttl != null
                        && (ttl.isZero() || ttl.isNegative())
        ) {
            throw new IllegalArgumentException(
                    "ttl must be positive"
            );
        }
    }
}
