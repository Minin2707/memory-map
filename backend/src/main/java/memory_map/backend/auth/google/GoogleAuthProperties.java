package memory_map.backend.auth.google;

import jakarta.validation.constraints.NotBlank;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

@ConfigurationProperties(prefix = "app.auth.google")
@Validated
public record GoogleAuthProperties(

        @NotBlank String clientId

) {
}
