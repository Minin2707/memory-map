package memory_map.backend.media.storage.minio;

import io.minio.BucketExistsArgs;
import io.minio.MinioClient;
import memory_map.backend.media.storage.StorageByteRange;
import memory_map.backend.media.storage.StorageException;
import memory_map.backend.media.storage.StorageKey;
import memory_map.backend.media.storage.StorageObjectNotFoundException;
import memory_map.backend.media.storage.StorageObjectWrite;
import memory_map.backend.media.storage.StorageService;
import memory_map.backend.media.storage.StorageStreamWrite;
import memory_map.backend.media.storage.StoredObject;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.containers.wait.strategy.Wait;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.utility.DockerImageName;

import java.io.InputStream;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.assertj.core.api.Assertions.catchThrowable;

@Testcontainers
class MinioStorageServiceIntegrationTest {

    private static final String ACCESS_KEY = "minio";
    private static final String SECRET_KEY = "minio-password";
    private static final String INVALID_ACCESS_KEY = "invalid-access-key";
    private static final String INVALID_SECRET_KEY = "invalid-secret-key";
    private static final String BUCKET = "photos";

    @Container
    private static final GenericContainer<?> minio =
            new GenericContainer<>(
                    DockerImageName.parse(
                            "minio/minio:RELEASE.2025-07-23T15-54-02Z"
                    )
            )
                    .withEnv("MINIO_ROOT_USER", ACCESS_KEY)
                    .withEnv("MINIO_ROOT_PASSWORD", SECRET_KEY)
                    .withCommand("server", "/data")
                    .withExposedPorts(9000)
                    .waitingFor(Wait.forHttp("/minio/health/ready")
                            .forPort(9000));

    private StorageService storageService;
    private MinioClient minioClient;

    @BeforeEach
    void setUp() {
        minioClient = MinioClient.builder()
                .endpoint(endpoint())
                .credentials(ACCESS_KEY, SECRET_KEY)
                .build();

        new MinioBucketInitializer(minioClient, BUCKET).initialize();
        storageService = new MinioStorageService(minioClient, BUCKET);
    }

    @Test
    void shouldBootstrapBucketWhenMissing() throws Exception {
        assertThat(minioClient.bucketExists(
                BucketExistsArgs.builder()
                        .bucket(BUCKET)
                        .build()
        )).isTrue();
    }

    @Test
    void shouldDenyAnonymousObjectReadFromBootstrappedBucket()
            throws Exception {
        StorageKey key = storageKey("anonymous-denied");
        byte[] content = new byte[] {9, 8, 7};
        storageService.store(new StorageObjectWrite(
                key,
                content,
                "image/jpeg"
        ));
        HttpClient anonymousClient = HttpClient.newHttpClient();
        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(endpoint() + "/" + BUCKET + "/" + key.value()))
                .GET()
                .build();

        HttpResponse<byte[]> response = anonymousClient.send(
                request,
                HttpResponse.BodyHandlers.ofByteArray()
        );

        assertThat(response.statusCode()).isEqualTo(403);
        assertThat(response.body()).isNotEqualTo(content);
    }

    @Test
    void shouldStoreAndReadExactObject() throws Exception {
        StorageKey key = storageKey("display");
        StorageObjectWrite object = new StorageObjectWrite(
                key,
                new byte[] {1, 2, 3},
                "image/jpeg"
        );

        storageService.store(object);

        StoredObject stored = storageService.read(key);
        try (InputStream content = stored.content()) {
            assertThat(content.readAllBytes()).containsExactly(1, 2, 3);
        }
        assertThat(stored.contentLength()).isEqualTo(3L);
        assertThat(stored.contentType()).isEqualTo("image/jpeg");
    }

    @Test
    void shouldStoreAndReadStreamObject() throws Exception {
        StorageKey key = storageKey("audio");

        try (InputStream input = new java.io.ByteArrayInputStream(
                new byte[] {1, 2, 3}
        )) {
            storageService.store(new StorageStreamWrite(
                    key,
                    input,
                    3L,
                    "audio/mpeg"
            ));
        }

        StoredObject stored = storageService.read(key);
        try (InputStream content = stored.content()) {
            assertThat(content.readAllBytes()).containsExactly(1, 2, 3);
        }
        assertThat(stored.contentLength()).isEqualTo(3L);
        assertThat(stored.contentType()).isEqualTo("audio/mpeg");
    }

    @Test
    void shouldKeepObjectsIsolatedByOpaqueKey() throws Exception {
        StorageKey first = storageKey("first");
        StorageKey second = storageKey("second");

        storageService.store(new StorageObjectWrite(
                first,
                new byte[] {1},
                "image/jpeg"
        ));
        storageService.store(new StorageObjectWrite(
                second,
                new byte[] {2},
                "image/jpeg"
        ));

        try (InputStream content = storageService.read(first).content()) {
            assertThat(content.readAllBytes()).containsExactly(1);
        }
        try (InputStream content = storageService.read(second).content()) {
            assertThat(content.readAllBytes()).containsExactly(2);
        }
    }

    @Test
    void shouldReadRangeFromStartWithoutLoadingFullObject() throws Exception {
        StorageKey key = storageKey("range-start");
        storageService.store(new StorageObjectWrite(
                key,
                new byte[] {1, 2, 3, 4, 5},
                "audio/mpeg"
        ));

        StoredObject stored = storageService.readRange(
                key,
                new StorageByteRange(0L, 2L)
        );

        try (InputStream content = stored.content()) {
            assertThat(content.readAllBytes()).containsExactly(1, 2);
        }
        assertThat(stored.contentLength()).isEqualTo(2L);
        assertThat(stored.contentType()).isEqualTo("audio/mpeg");
    }

    @Test
    void shouldReadRangeFromMiddleWithoutLoadingFullObject() throws Exception {
        StorageKey key = storageKey("range-middle");
        storageService.store(new StorageObjectWrite(
                key,
                new byte[] {1, 2, 3, 4, 5},
                "audio/mpeg"
        ));

        StoredObject stored = storageService.readRange(
                key,
                new StorageByteRange(2L, 2L)
        );

        try (InputStream content = stored.content()) {
            assertThat(content.readAllBytes()).containsExactly(3, 4);
        }
        assertThat(stored.contentLength()).isEqualTo(2L);
        assertThat(stored.contentType()).isEqualTo("audio/mpeg");
    }

    @Test
    void shouldReadRangeEndingAtObjectEnd() throws Exception {
        StorageKey key = storageKey("range-end");
        storageService.store(new StorageObjectWrite(
                key,
                new byte[] {1, 2, 3, 4, 5},
                "audio/mpeg"
        ));

        StoredObject stored = storageService.readRange(
                key,
                new StorageByteRange(3L, 2L)
        );

        try (InputStream content = stored.content()) {
            assertThat(content.readAllBytes()).containsExactly(4, 5);
        }
        assertThat(stored.contentLength()).isEqualTo(2L);
        assertThat(stored.contentType()).isEqualTo("audio/mpeg");
    }

    @Test
    void shouldDeleteObjectAndTreatRepeatedDeleteAsNoOp() {
        StorageKey key = storageKey("delete");
        storageService.store(new StorageObjectWrite(
                key,
                new byte[] {1},
                "image/jpeg"
        ));

        storageService.delete(key);

        assertThatThrownBy(() -> storageService.read(key))
                .isInstanceOf(StorageObjectNotFoundException.class);
        assertThatCode(() -> storageService.delete(key))
                .doesNotThrowAnyException();
    }

    @Test
    void shouldMapMissingReadToStorageObjectNotFound() {
        StorageKey key = storageKey("missing");

        Throwable thrown = catchThrowable(() -> storageService.read(key));

        assertThat(thrown)
                .isInstanceOf(StorageObjectNotFoundException.class)
                .hasMessage("Storage object was not found");
        assertThat(thrown.getMessage())
                .doesNotContain(key.value())
                .doesNotContain(endpoint())
                .doesNotContain(SECRET_KEY);
    }

    @Test
    void shouldMapMissingRangedReadToStorageObjectNotFound() {
        StorageKey key = storageKey("missing-range");

        Throwable thrown = catchThrowable(() -> storageService.readRange(
                key,
                new StorageByteRange(0L, 1L)
        ));

        assertThat(thrown)
                .isInstanceOf(StorageObjectNotFoundException.class)
                .hasMessage("Storage object was not found");
        assertThat(thrown.getMessage())
                .doesNotContain(key.value())
                .doesNotContain(endpoint())
                .doesNotContain(SECRET_KEY);
    }

    @Test
    void shouldMapRealMinioAuthFailureToGenericStorageException() {
        StorageKey key = storageKey("invalid-credentials");
        storageService.store(new StorageObjectWrite(
                key,
                new byte[] {4, 5, 6},
                "image/jpeg"
        ));
        MinioClient invalidClient = MinioClient.builder()
                .endpoint(endpoint())
                .credentials(INVALID_ACCESS_KEY, INVALID_SECRET_KEY)
                .build();
        StorageService invalidStorageService =
                new MinioStorageService(invalidClient, BUCKET);

        Throwable thrown = catchThrowable(
                () -> invalidStorageService.read(key)
        );

        assertThat(thrown)
                .isInstanceOf(StorageException.class)
                .isNotInstanceOf(StorageObjectNotFoundException.class)
                .hasMessage("Storage operation failed");
        assertMessageDoesNotExpose(thrown, key.value());
        assertMessageDoesNotExpose(thrown, endpoint());
        assertMessageDoesNotExpose(thrown, SECRET_KEY);
        assertMessageDoesNotExpose(thrown, INVALID_SECRET_KEY);
    }

    private static StorageKey storageKey(String suffix) {
        return new StorageKey(
                "media/" + UUID.randomUUID() + "/" + suffix
        );
    }

    private static String endpoint() {
        return "http://" + minio.getHost() + ":"
                + minio.getMappedPort(9000);
    }

    private static void assertMessageDoesNotExpose(
            Throwable thrown,
            String sensitiveValue
    ) {
        assertThat(thrown.getMessage().contains(sensitiveValue)).isFalse();
    }
}
