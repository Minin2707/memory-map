package memory_map.backend.media.image;

import java.util.Objects;
import java.util.Set;

public record ImageProcessingPolicy(

        long maxUploadBytes,

        long maxDecodedPixels,

        int maxDimension,

        int displayMaxLongSide,

        int thumbnailMaxLongSide,

        Set<String> acceptedInputContentTypes,

        String outputMimeType,

        int outputJpegQuality

) {
    public static final long DEFAULT_MAX_UPLOAD_BYTES = 5L * 1024L * 1024L;
    public static final long DEFAULT_MAX_DECODED_PIXELS = 16_000_000L;
    public static final int DEFAULT_MAX_DIMENSION = 4_096;
    public static final int DEFAULT_DISPLAY_MAX_LONG_SIDE = 2_048;
    public static final int DEFAULT_THUMBNAIL_MAX_LONG_SIDE = 360;
    public static final String DEFAULT_OUTPUT_MIME_TYPE = "image/jpeg";
    public static final int DEFAULT_OUTPUT_JPEG_QUALITY = 85;

    public ImageProcessingPolicy {
        Objects.requireNonNull(
                acceptedInputContentTypes,
                "acceptedInputContentTypes must not be null"
        );
        Objects.requireNonNull(outputMimeType, "outputMimeType must not be null");

        if (maxUploadBytes <= 0) {
            throw new IllegalArgumentException("maxUploadBytes must be positive");
        }

        if (maxDecodedPixels <= 0) {
            throw new IllegalArgumentException(
                    "maxDecodedPixels must be positive"
            );
        }

        if (maxDimension <= 0) {
            throw new IllegalArgumentException("maxDimension must be positive");
        }

        if (displayMaxLongSide <= 0) {
            throw new IllegalArgumentException(
                    "displayMaxLongSide must be positive"
            );
        }

        if (thumbnailMaxLongSide <= 0) {
            throw new IllegalArgumentException(
                    "thumbnailMaxLongSide must be positive"
            );
        }

        if (displayMaxLongSide > maxDimension) {
            throw new IllegalArgumentException(
                    "displayMaxLongSide must not exceed maxDimension"
            );
        }

        if (thumbnailMaxLongSide > displayMaxLongSide) {
            throw new IllegalArgumentException(
                    "thumbnailMaxLongSide must not exceed displayMaxLongSide"
            );
        }

        if (acceptedInputContentTypes.isEmpty()) {
            throw new IllegalArgumentException(
                    "acceptedInputContentTypes must not be empty"
            );
        }

        for (String contentType : acceptedInputContentTypes) {
            if (contentType == null || contentType.isBlank()) {
                throw new IllegalArgumentException(
                        "acceptedInputContentTypes must not contain blank values"
                );
            }
        }

        if (outputMimeType.isBlank()) {
            throw new IllegalArgumentException(
                    "outputMimeType must not be blank"
            );
        }

        if (outputJpegQuality < 1 || outputJpegQuality > 100) {
            throw new IllegalArgumentException(
                    "outputJpegQuality must be between 1 and 100"
            );
        }

        acceptedInputContentTypes = Set.copyOf(acceptedInputContentTypes);
    }

    public static ImageProcessingPolicy mvpDefaults() {
        return new ImageProcessingPolicy(
                DEFAULT_MAX_UPLOAD_BYTES,
                DEFAULT_MAX_DECODED_PIXELS,
                DEFAULT_MAX_DIMENSION,
                DEFAULT_DISPLAY_MAX_LONG_SIDE,
                DEFAULT_THUMBNAIL_MAX_LONG_SIDE,
                Set.of("image/jpeg", "image/png"),
                DEFAULT_OUTPUT_MIME_TYPE,
                DEFAULT_OUTPUT_JPEG_QUALITY
        );
    }

    @Override
    public String toString() {
        return "ImageProcessingPolicy[maxUploadBytes=%d, maxDecodedPixels=%d, maxDimension=%d, displayMaxLongSide=%d, thumbnailMaxLongSide=%d, outputMimeType=%s, outputJpegQuality=%d]"
                .formatted(
                        maxUploadBytes,
                        maxDecodedPixels,
                        maxDimension,
                        displayMaxLongSide,
                        thumbnailMaxLongSide,
                        outputMimeType,
                        outputJpegQuality
                );
    }
}
