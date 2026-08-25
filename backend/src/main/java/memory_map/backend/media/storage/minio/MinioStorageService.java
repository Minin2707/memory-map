package memory_map.backend.media.storage.minio;

import io.minio.GetObjectArgs;
import io.minio.MinioClient;
import io.minio.PutObjectArgs;
import io.minio.RemoveObjectArgs;
import io.minio.StatObjectArgs;
import io.minio.StatObjectResponse;
import io.minio.errors.ErrorResponseException;
import memory_map.backend.media.storage.StorageByteRange;
import memory_map.backend.media.storage.StorageException;
import memory_map.backend.media.storage.StorageKey;
import memory_map.backend.media.storage.StorageObjectNotFoundException;
import memory_map.backend.media.storage.StorageObjectWrite;
import memory_map.backend.media.storage.StorageService;
import memory_map.backend.media.storage.StorageStreamWrite;
import memory_map.backend.media.storage.StoredObject;

import java.io.ByteArrayInputStream;
import java.io.InputStream;
import java.util.Objects;

public final class MinioStorageService implements StorageService {

    private final MinioClient minioClient;
    private final String bucket;

    public MinioStorageService(
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

    @Override
    public void store(StorageObjectWrite object) {
        Objects.requireNonNull(object, "object must not be null");

        try {
            minioClient.putObject(
                    PutObjectArgs.builder()
                            .bucket(bucket)
                            .object(object.storageKey().value())
                            .stream(
                                    new ByteArrayInputStream(object.content()),
                                    object.contentLength(),
                                    -1L
                            )
                            .contentType(object.contentType())
                            .build()
            );
        } catch (Exception exception) {
            throw new StorageException(exception);
        }
    }

    @Override
    public void store(StorageStreamWrite object) {
        Objects.requireNonNull(object, "object must not be null");

        try {
            minioClient.putObject(
                    PutObjectArgs.builder()
                            .bucket(bucket)
                            .object(object.storageKey().value())
                            .stream(
                                    object.content(),
                                    object.contentLength(),
                                    -1L
                            )
                            .contentType(object.contentType())
                            .build()
            );
        } catch (Exception exception) {
            throw new StorageException(exception);
        }
    }

    @Override
    public StoredObject read(StorageKey storageKey) {
        Objects.requireNonNull(storageKey, "storageKey must not be null");

        try {
            StatObjectResponse stat = minioClient.statObject(
                    StatObjectArgs.builder()
                            .bucket(bucket)
                            .object(storageKey.value())
                            .build()
            );
            InputStream content = minioClient.getObject(
                    GetObjectArgs.builder()
                            .bucket(bucket)
                            .object(storageKey.value())
                            .build()
            );

            return new StoredObject(
                    content,
                    stat.size(),
                    stat.contentType()
            );
        } catch (Exception exception) {
            if (isObjectNotFound(exception)) {
                throw new StorageObjectNotFoundException();
            }

            throw new StorageException(exception);
        }
    }

    @Override
    public StoredObject readRange(
            StorageKey storageKey,
            StorageByteRange range
    ) {
        Objects.requireNonNull(storageKey, "storageKey must not be null");
        Objects.requireNonNull(range, "range must not be null");

        try {
            StatObjectResponse stat = minioClient.statObject(
                    StatObjectArgs.builder()
                            .bucket(bucket)
                            .object(storageKey.value())
                            .build()
            );
            InputStream content = minioClient.getObject(
                    GetObjectArgs.builder()
                            .bucket(bucket)
                            .object(storageKey.value())
                            .offset(range.offset())
                            .length(range.length())
                            .build()
            );

            return new StoredObject(
                    content,
                    range.length(),
                    stat.contentType()
            );
        } catch (Exception exception) {
            if (isObjectNotFound(exception)) {
                throw new StorageObjectNotFoundException();
            }

            throw new StorageException(exception);
        }
    }

    @Override
    public void delete(StorageKey storageKey) {
        Objects.requireNonNull(storageKey, "storageKey must not be null");

        try {
            minioClient.removeObject(
                    RemoveObjectArgs.builder()
                            .bucket(bucket)
                            .object(storageKey.value())
                            .build()
            );
        } catch (Exception exception) {
            if (isObjectNotFound(exception)) {
                return;
            }

            throw new StorageException(exception);
        }
    }

    private static boolean isObjectNotFound(Exception exception) {
        if (!(exception instanceof ErrorResponseException error)) {
            return false;
        }

        String code = error.errorResponse().code();

        return code.equals("NoSuchKey")
                || code.equals("NoSuchObject");
    }
}
