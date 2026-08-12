package memory_map.backend.media.image.jvm;

import memory_map.backend.media.image.ImageProcessingInput;
import memory_map.backend.media.image.ImageProcessingPolicy;
import memory_map.backend.media.image.InvalidImageException;
import memory_map.backend.media.image.InvalidImageReason;
import memory_map.backend.media.image.ProcessedPhoto;
import org.junit.jupiter.api.Test;

import javax.imageio.ImageIO;
import java.awt.Color;
import java.awt.Graphics2D;
import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.catchThrowable;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class JvmImageProcessorTest {

    @Test
    void shouldProcessValidJpegIntoDisplayAndThumbnailJpegs()
            throws Exception {

        JvmImageProcessor processor = processor(policy(
                1_000_000L,
                1_000_000L,
                1_000,
                200,
                50
        ));

        ProcessedPhoto photo = processor.process(new ImageProcessingInput(
                imageBytes(800, 400, "jpeg"),
                "image/jpeg"
        ));

        assertThat(photo.mimeType()).isEqualTo("image/jpeg");
        assertImageDimensions(photo.display().content(), 200, 100);
        assertImageDimensions(photo.thumbnail().content(), 50, 25);
    }

    @Test
    void shouldProcessValidPngIntoJpegOutput() throws Exception {
        JvmImageProcessor processor = processor(ImageProcessingPolicy.mvpDefaults());

        ProcessedPhoto photo = processor.process(new ImageProcessingInput(
                imageBytes(40, 20, "png"),
                "image/png"
        ));

        assertThat(photo.mimeType()).isEqualTo("image/jpeg");
        assertThat(detectedFormat(photo.display().content()))
                .isEqualTo("JPEG");
        assertThat(detectedFormat(photo.thumbnail().content()))
                .isEqualTo("JPEG");
    }

    @Test
    void shouldRejectMimeMismatch() {
        JvmImageProcessor processor = processor(ImageProcessingPolicy.mvpDefaults());

        assertInvalidReason(
                () -> processor.process(new ImageProcessingInput(
                        imageBytes(40, 20, "jpeg"),
                        "image/png"
                )),
                InvalidImageReason.MIME_MISMATCH
        );

        assertInvalidReason(
                () -> processor.process(new ImageProcessingInput(
                        imageBytes(40, 20, "png"),
                        "image/jpeg"
                )),
                InvalidImageReason.MIME_MISMATCH
        );
    }

    @Test
    void shouldRejectRandomBytesAsInvalidImage() {
        JvmImageProcessor processor = processor(ImageProcessingPolicy.mvpDefaults());

        assertInvalidReason(
                () -> processor.process(new ImageProcessingInput(
                        new byte[] {1, 2, 3},
                        "image/jpeg"
                )),
                InvalidImageReason.INVALID_IMAGE
        );
    }

    @Test
    void shouldRejectUnsupportedActualFormat() {
        JvmImageProcessor processor = processor(ImageProcessingPolicy.mvpDefaults());

        assertInvalidReason(
                () -> processor.process(new ImageProcessingInput(
                        imageBytes(20, 20, "gif"),
                        "image/gif"
                )),
                InvalidImageReason.UNSUPPORTED_TYPE
        );
    }

    @Test
    void shouldRejectTooLargeUploadBeforeDecode() {
        JvmImageProcessor processor = processor(ImageProcessingPolicy.mvpDefaults());

        assertInvalidReason(
                () -> processor.process(new ImageProcessingInput(
                        new byte[(int) ImageProcessingPolicy.DEFAULT_MAX_UPLOAD_BYTES + 1],
                        "image/jpeg"
                )),
                InvalidImageReason.TOO_LARGE
        );
    }

    @Test
    void shouldRejectExceededDimensions() {
        JvmImageProcessor processor = processor(policy(
                1_000_000L,
                100L,
                1_000,
                200,
                50
        ));

        assertInvalidReason(
                () -> processor.process(new ImageProcessingInput(
                        imageBytes(20, 20, "png"),
                        "image/png"
                )),
                InvalidImageReason.DIMENSIONS_EXCEEDED
        );
    }

    @Test
    void shouldNeverUpscaleSmallImages() throws Exception {
        JvmImageProcessor processor = processor(policy(
                1_000_000L,
                1_000_000L,
                1_000,
                200,
                50
        ));

        ProcessedPhoto photo = processor.process(new ImageProcessingInput(
                imageBytes(40, 20, "jpeg"),
                "image/jpeg"
        ));

        assertImageDimensions(photo.display().content(), 40, 20);
        assertImageDimensions(photo.thumbnail().content(), 40, 20);
    }

    @Test
    void shouldApplyExifOrientationBeforeStrippingMetadata()
            throws Exception {

        JvmImageProcessor processor = processor(ImageProcessingPolicy.mvpDefaults());
        byte[] jpeg = withExifOrientation(
                imageBytes(40, 20, "jpeg"),
                6
        );

        ProcessedPhoto photo = processor.process(new ImageProcessingInput(
                jpeg,
                "image/jpeg"
        ));

        assertImageDimensions(photo.display().content(), 20, 40);
        assertThat(new String(photo.display().content(), StandardCharsets.ISO_8859_1))
                .doesNotContain("Exif");
    }

    @Test
    void shouldCompositePngAlphaAgainstWhiteBeforeJpegEncoding()
            throws Exception {

        JvmImageProcessor processor = processor(ImageProcessingPolicy.mvpDefaults());
        ProcessedPhoto photo = processor.process(new ImageProcessingInput(
                transparentPng(),
                "image/png"
        ));

        BufferedImage decoded = ImageIO.read(new ByteArrayInputStream(
                photo.display().content()
        ));
        Color pixel = new Color(decoded.getRGB(0, 0));

        assertThat(pixel.getRed()).isGreaterThan(230);
        assertThat(pixel.getGreen()).isGreaterThan(230);
        assertThat(pixel.getBlue()).isGreaterThan(230);
    }

    @Test
    void shouldHaveSafeExceptionDiagnostics() {
        JvmImageProcessor processor = processor(ImageProcessingPolicy.mvpDefaults());

        Throwable thrown = catchThrowable(() -> processor.process(new ImageProcessingInput(
                new byte[] {1, 2, 3},
                "image/jpeg"
        )));

        assertThat(thrown)
                .isInstanceOf(InvalidImageException.class)
                .hasMessage("Image is invalid");
        assertThat(thrown.getMessage())
                .doesNotContain("image/jpeg")
                .doesNotContain("[1, 2, 3]");
    }

    private static JvmImageProcessor processor(ImageProcessingPolicy policy) {
        return new JvmImageProcessor(policy);
    }

    private static ImageProcessingPolicy policy(
            long maxUploadBytes,
            long maxDecodedPixels,
            int maxDimension,
            int displayMaxLongSide,
            int thumbnailMaxLongSide
    ) {
        return new ImageProcessingPolicy(
                maxUploadBytes,
                maxDecodedPixels,
                maxDimension,
                displayMaxLongSide,
                thumbnailMaxLongSide,
                Set.of("image/jpeg", "image/png"),
                "image/jpeg",
                85
        );
    }

    private static byte[] imageBytes(
            int width,
            int height,
            String format
    ) {
        try {
            BufferedImage image = new BufferedImage(
                    width,
                    height,
                    BufferedImage.TYPE_INT_RGB
            );
            Graphics2D graphics = image.createGraphics();
            try {
                graphics.setColor(Color.BLUE);
                graphics.fillRect(0, 0, width, height);
            } finally {
                graphics.dispose();
            }

            ByteArrayOutputStream output = new ByteArrayOutputStream();
            ImageIO.write(image, format, output);

            return output.toByteArray();
        } catch (IOException exception) {
            throw new IllegalStateException(exception);
        }
    }

    private static byte[] transparentPng() {
        try {
            BufferedImage image = new BufferedImage(
                    20,
                    20,
                    BufferedImage.TYPE_INT_ARGB
            );
            Graphics2D graphics = image.createGraphics();
            try {
                graphics.setColor(new Color(255, 0, 0, 0));
                graphics.fillRect(0, 0, image.getWidth(), image.getHeight());
            } finally {
                graphics.dispose();
            }

            ByteArrayOutputStream output = new ByteArrayOutputStream();
            ImageIO.write(image, "png", output);

            return output.toByteArray();
        } catch (IOException exception) {
            throw new IllegalStateException(exception);
        }
    }

    private static void assertImageDimensions(
            byte[] content,
            int expectedWidth,
            int expectedHeight
    ) throws IOException {
        BufferedImage image = ImageIO.read(new ByteArrayInputStream(content));

        assertThat(image.getWidth()).isEqualTo(expectedWidth);
        assertThat(image.getHeight()).isEqualTo(expectedHeight);
    }

    private static String detectedFormat(byte[] content) throws IOException {
        try (
                var imageInput = ImageIO.createImageInputStream(
                        new ByteArrayInputStream(content)
                )
        ) {
            var readers = ImageIO.getImageReaders(imageInput);
            assertThat(readers.hasNext()).isTrue();
            var reader = readers.next();
            try {
                return reader.getFormatName();
            } finally {
                reader.dispose();
            }
        }
    }

    private static byte[] withExifOrientation(
            byte[] jpeg,
            int orientation
    ) {
        byte[] exif = exifOrientationSegment(orientation);
        byte[] result = new byte[jpeg.length + exif.length];

        result[0] = jpeg[0];
        result[1] = jpeg[1];
        System.arraycopy(exif, 0, result, 2, exif.length);
        System.arraycopy(jpeg, 2, result, 2 + exif.length, jpeg.length - 2);

        return result;
    }

    private static byte[] exifOrientationSegment(int orientation) {
        byte[] payload = new byte[] {
                'E', 'x', 'i', 'f', 0, 0,
                'M', 'M', 0, 42,
                0, 0, 0, 8,
                0, 1,
                0x01, 0x12,
                0, 3,
                0, 0, 0, 1,
                0, (byte) orientation, 0, 0,
                0, 0, 0, 0
        };
        int length = payload.length + 2;
        byte[] segment = new byte[payload.length + 4];

        segment[0] = (byte) 0xFF;
        segment[1] = (byte) 0xE1;
        segment[2] = (byte) ((length >> 8) & 0xFF);
        segment[3] = (byte) (length & 0xFF);
        System.arraycopy(payload, 0, segment, 4, payload.length);

        return segment;
    }

    private static void assertInvalidReason(
            ThrowingRunnable runnable,
            InvalidImageReason reason
    ) {
        assertThatThrownBy(runnable::run)
                .isInstanceOf(InvalidImageException.class)
                .satisfies(exception -> assertThat(
                        ((InvalidImageException) exception).reason()
                ).isEqualTo(reason));
    }

    @FunctionalInterface
    private interface ThrowingRunnable {

        void run() throws Exception;
    }
}
