package memory_map.backend.invite.application;

import jakarta.validation.constraints.NotNull;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

import java.net.URI;
import java.time.Duration;
import java.util.Locale;
import java.util.Objects;

@ConfigurationProperties(prefix = "app.invite")
@Validated
public record InviteProperties(

        @NotNull Duration ttl,

        @NotNull URI baseUrl

) {
    public InviteProperties {
        if (
                ttl != null
                        && (ttl.isZero() || ttl.isNegative())
        ) {
            throw new IllegalArgumentException("ttl must be positive");
        }

        if (baseUrl != null) {
            baseUrl = normalizeBaseUrl(baseUrl);
        }
    }

    private static URI normalizeBaseUrl(URI baseUrl) {
        if (!baseUrl.isAbsolute()) {
            throw new IllegalArgumentException(
                    "baseUrl must be absolute"
            );
        }

        String scheme = Objects.requireNonNull(
                baseUrl.getScheme(),
                "baseUrl scheme must not be null"
        ).toLowerCase(Locale.ROOT);

        if (!scheme.equals("https") && !scheme.equals("http")) {
            throw new IllegalArgumentException(
                    "baseUrl scheme must be http or https"
            );
        }

        if (baseUrl.getHost() == null) {
            throw new IllegalArgumentException(
                    "baseUrl host must not be null"
            );
        }

        if (baseUrl.getUserInfo() != null) {
            throw new IllegalArgumentException(
                    "baseUrl user info must not be present"
            );
        }

        if (baseUrl.getQuery() != null) {
            throw new IllegalArgumentException(
                    "baseUrl query must not be present"
            );
        }

        if (baseUrl.getFragment() != null) {
            throw new IllegalArgumentException(
                    "baseUrl fragment must not be present"
            );
        }

        String path = baseUrl.getPath();
        if (path != null && !path.isBlank() && !path.equals("/")) {
            throw new IllegalArgumentException(
                    "baseUrl path must not be present"
            );
        }

        return URI.create(scheme + "://" + baseUrl.getRawAuthority());
    }
}
