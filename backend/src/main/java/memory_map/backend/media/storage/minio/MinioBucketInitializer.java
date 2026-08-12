package memory_map.backend.media.storage.minio;

import io.minio.BucketExistsArgs;
import io.minio.MakeBucketArgs;
import io.minio.MinioClient;
import memory_map.backend.media.storage.StorageException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.Objects;

public final class MinioBucketInitializer {

    private static final Logger log =
            LoggerFactory.getLogger(MinioBucketInitializer.class);

    private final MinioClient minioClient;
    private final String bucket;

    public MinioBucketInitializer(
            MinioClient minioClient,
            String bucket
    ) {
        this.minioClient = Objects.requireNonNull(
                minioClient,
                "minioClient must not be null"
        );
        this.bucket = Objects.requireNonNull(bucket, "bucket must not be null");

        if (bucket.isBlank()) {
            throw new IllegalArgumentException("bucket must not be blank");
        }
    }

    public void initialize() {
        try {
            boolean exists = minioClient.bucketExists(
                    BucketExistsArgs.builder()
                            .bucket(bucket)
                            .build()
            );

            if (!exists) {
                minioClient.makeBucket(
                        MakeBucketArgs.builder()
                                .bucket(bucket)
                                .build()
                );
            }

            log.info("Media object storage initialized");
        } catch (Exception exception) {
            throw new StorageException(exception);
        }
    }
}
