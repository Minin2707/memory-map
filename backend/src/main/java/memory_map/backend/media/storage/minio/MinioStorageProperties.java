package memory_map.backend.media.storage.minio;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

import java.net.URI;
import java.util.Locale;
import java.util.Objects;

@ConfigurationProperties(prefix = "app.storage.minio")
@Validated
public record MinioStorageProperties(

        boolean enabled,

        URI endpoint,

        String accessKey,

        String secretKey,

        String bucket

) {
    public MinioStorageProperties {
        if (enabled) {
            Objects.requireNonNull(endpoint, "endpoint must not be null");
            Objects.requireNonNull(accessKey, "accessKey must not be null");
            Objects.requireNonNull(secretKey, "secretKey must not be null");
            Objects.requireNonNull(bucket, "bucket must not be null");

            endpoint = normalizeEndpoint(endpoint);

            if (accessKey.isBlank()) {
                throw new IllegalArgumentException(
                        "accessKey must not be blank"
                );
            }

            if (secretKey.isBlank()) {
                throw new IllegalArgumentException(
                        "secretKey must not be blank"
                );
            }

            if (bucket.isBlank()) {
                throw new IllegalArgumentException("bucket must not be blank");
            }
        }
    }

    private static URI normalizeEndpoint(URI endpoint) {
        if (!endpoint.isAbsolute()) {
            throw new IllegalArgumentException("endpoint must be absolute");
        }

        String scheme = Objects.requireNonNull(
                endpoint.getScheme(),
                "endpoint scheme must not be null"
        ).toLowerCase(Locale.ROOT);

        if (!scheme.equals("http") && !scheme.equals("https")) {
            throw new IllegalArgumentException(
                    "endpoint scheme must be http or https"
            );
        }

        if (endpoint.getHost() == null) {
            throw new IllegalArgumentException(
                    "endpoint host must not be null"
            );
        }

        if (endpoint.getUserInfo() != null) {
            throw new IllegalArgumentException(
                    "endpoint user info must not be present"
            );
        }

        if (endpoint.getQuery() != null) {
            throw new IllegalArgumentException(
                    "endpoint query must not be present"
            );
        }

        if (endpoint.getFragment() != null) {
            throw new IllegalArgumentException(
                    "endpoint fragment must not be present"
            );
        }

        String path = endpoint.getPath();
        if (path != null && !path.isBlank() && !path.equals("/")) {
            throw new IllegalArgumentException(
                    "endpoint path must not be present"
            );
        }

        return URI.create(scheme + "://" + endpoint.getRawAuthority());
    }

    @Override
    public String toString() {
        return "MinioStorageProperties[enabled=%s, hasEndpoint=%s, hasAccessKey=%s, hasSecretKey=%s, hasBucket=%s]"
                .formatted(
                        enabled,
                        endpoint != null,
                        accessKey != null && !accessKey.isBlank(),
                        secretKey != null && !secretKey.isBlank(),
                        bucket != null && !bucket.isBlank()
                );
    }
}
