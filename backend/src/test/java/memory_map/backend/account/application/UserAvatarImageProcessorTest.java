package memory_map.backend.account.application;

import memory_map.backend.media.image.ImageProcessingException;
import memory_map.backend.media.image.ImageProcessingInput;
import memory_map.backend.media.image.ImageProcessor;
import memory_map.backend.media.image.InvalidImageException;
import memory_map.backend.media.image.InvalidImageReason;
import memory_map.backend.media.image.ProcessedImage;
import memory_map.backend.media.image.ProcessedPhoto;
import org.junit.jupiter.api.Test;

import javax.imageio.ImageIO;
import java.awt.Color;
import java.awt.Graphics2D;
import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.UncheckedIOException;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class UserAvatarImageProcessorTest {

    private static final ImageProcessingInput INPUT =
            new ImageProcessingInput(new byte[] {1, 2, 3}, "image/png");

    @Test
    void shouldRejectNullImageProcessor() {
        assertThatThrownBy(() -> new UserAvatarImageProcessor(null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("imageProcessor must not be null");
    }

    @Test
    void shouldTranslateInvalidImageException() {
        InvalidImageException failure =
                new InvalidImageException(InvalidImageReason.INVALID_IMAGE);
        FakeImageProcessor imageProcessor = new FakeImageProcessor();
        imageProcessor.failure = failure;

        assertThatThrownBy(() -> service(imageProcessor).process(INPUT))
                .isInstanceOf(InvalidUserAvatarException.class)
                .hasCause(failure);
        assertThat(imageProcessor.receivedInput).isEqualTo(INPUT);
    }

    @Test
    void shouldTranslateImageProcessingException() {
        ImageProcessingException failure = new ImageProcessingException();
        FakeImageProcessor imageProcessor = new FakeImageProcessor();
        imageProcessor.failure = failure;

        assertThatThrownBy(() -> service(imageProcessor).process(INPUT))
                .isInstanceOf(InvalidUserAvatarException.class)
                .hasCause(failure);
        assertThat(imageProcessor.receivedInput).isEqualTo(INPUT);
    }

    @Test
    void shouldRejectInvalidNormalizedImageBytes() {
        FakeImageProcessor imageProcessor = new FakeImageProcessor();
        imageProcessor.result = processedPhoto(new byte[] {1, 2, 3});

        assertThatThrownBy(() -> service(imageProcessor).process(INPUT))
                .isInstanceOf(InvalidUserAvatarException.class)
                .hasCauseInstanceOf(ImageProcessingException.class);
    }

    @Test
    void shouldCenterCropHorizontalImageAndResizeToAvatarSize()
            throws Exception {

        FakeImageProcessor imageProcessor = new FakeImageProcessor();
        imageProcessor.result = processedPhoto(horizontalSourceBytes());

        ProcessedUserAvatar avatar = service(imageProcessor).process(INPUT);
        BufferedImage output = decode(avatar.content());

        assertAvatarImage(output);
        assertGreenDominant(output.getRGB(256, 256));
        assertGreenDominant(output.getRGB(32, 32));
        assertGreenDominant(output.getRGB(480, 480));
        assertThat(imageProcessor.receivedInput).isEqualTo(INPUT);
    }

    @Test
    void shouldCenterCropVerticalImageAndResizeToAvatarSize()
            throws Exception {

        FakeImageProcessor imageProcessor = new FakeImageProcessor();
        imageProcessor.result = processedPhoto(verticalSourceBytes());

        ProcessedUserAvatar avatar = service(imageProcessor).process(INPUT);
        BufferedImage output = decode(avatar.content());

        assertAvatarImage(output);
        assertGreenDominant(output.getRGB(256, 256));
        assertGreenDominant(output.getRGB(32, 32));
        assertGreenDominant(output.getRGB(480, 480));
    }

    @Test
    void shouldKeepAlreadyAvatarSizedSquareAtAvatarSize() throws Exception {
        FakeImageProcessor imageProcessor = new FakeImageProcessor();
        imageProcessor.result = processedPhoto(squareSourceBytes(512));

        ProcessedUserAvatar avatar = service(imageProcessor).process(INPUT);
        BufferedImage output = decode(avatar.content());

        assertAvatarImage(output);
        assertPurpleDominant(output.getRGB(256, 256));
    }

    @Test
    void shouldResizeSmallerSquareImageToAvatarSize() throws Exception {
        FakeImageProcessor imageProcessor = new FakeImageProcessor();
        imageProcessor.result = processedPhoto(squareSourceBytes(64));

        ProcessedUserAvatar avatar = service(imageProcessor).process(INPUT);
        BufferedImage output = decode(avatar.content());

        assertAvatarImage(output);
        assertPurpleDominant(output.getRGB(256, 256));
    }

    @Test
    void shouldReportJpegContentTypeForJpegEncodedAvatar() throws Exception {
        FakeImageProcessor imageProcessor = new FakeImageProcessor();
        imageProcessor.result = processedPhoto(
                squareSourceBytes(64),
                "image/png"
        );

        ProcessedUserAvatar avatar = service(imageProcessor).process(INPUT);

        assertThat(avatar.contentType()).isEqualTo("image/jpeg");
        assertThat(avatar.content()[0] & 0xFF).isEqualTo(0xFF);
        assertThat(avatar.content()[1] & 0xFF).isEqualTo(0xD8);
        assertThat(decode(avatar.content())).isNotNull();
    }

    @Test
    void shouldEncodeSuccessfulOutputAsJpegImage() throws Exception {
        FakeImageProcessor imageProcessor = new FakeImageProcessor();
        imageProcessor.result = processedPhoto(squareSourceBytes(64));

        ProcessedUserAvatar avatar = service(imageProcessor).process(INPUT);

        assertThat(avatar.content()[0] & 0xFF).isEqualTo(0xFF);
        assertThat(avatar.content()[1] & 0xFF).isEqualTo(0xD8);
        assertThat(decode(avatar.content())).isNotNull();
    }

    private static UserAvatarImageProcessor service(
            FakeImageProcessor imageProcessor
    ) {
        return new UserAvatarImageProcessor(imageProcessor);
    }

    private static ProcessedPhoto processedPhoto(byte[] displayBytes) {
        return processedPhoto(displayBytes, "image/jpeg");
    }

    private static ProcessedPhoto processedPhoto(
            byte[] displayBytes,
            String mimeType
    ) {
        return new ProcessedPhoto(
                new ProcessedImage(displayBytes),
                new ProcessedImage(displayBytes),
                mimeType
        );
    }

    private static byte[] horizontalSourceBytes() {
        BufferedImage image = new BufferedImage(
                900,
                300,
                BufferedImage.TYPE_INT_RGB
        );
        Graphics2D graphics = image.createGraphics();
        try {
            graphics.setColor(Color.RED);
            graphics.fillRect(0, 0, 300, 300);
            graphics.setColor(Color.GREEN);
            graphics.fillRect(300, 0, 300, 300);
            graphics.setColor(Color.BLUE);
            graphics.fillRect(600, 0, 300, 300);
        } finally {
            graphics.dispose();
        }

        return encodePng(image);
    }

    private static byte[] verticalSourceBytes() {
        BufferedImage image = new BufferedImage(
                300,
                900,
                BufferedImage.TYPE_INT_RGB
        );
        Graphics2D graphics = image.createGraphics();
        try {
            graphics.setColor(Color.RED);
            graphics.fillRect(0, 0, 300, 300);
            graphics.setColor(Color.GREEN);
            graphics.fillRect(0, 300, 300, 300);
            graphics.setColor(Color.BLUE);
            graphics.fillRect(0, 600, 300, 300);
        } finally {
            graphics.dispose();
        }

        return encodePng(image);
    }

    private static byte[] squareSourceBytes(int size) {
        BufferedImage image = new BufferedImage(
                size,
                size,
                BufferedImage.TYPE_INT_RGB
        );
        Graphics2D graphics = image.createGraphics();
        try {
            graphics.setColor(new Color(128, 0, 128));
            graphics.fillRect(0, 0, size, size);
        } finally {
            graphics.dispose();
        }

        return encodePng(image);
    }

    private static byte[] encodePng(BufferedImage image) {
        try {
            ByteArrayOutputStream output = new ByteArrayOutputStream();
            ImageIO.write(image, "PNG", output);
            return output.toByteArray();
        } catch (IOException exception) {
            throw new UncheckedIOException(exception);
        }
    }

    private static BufferedImage decode(byte[] content) throws IOException {
        return ImageIO.read(new ByteArrayInputStream(content));
    }

    private static void assertAvatarImage(BufferedImage image) {
        assertThat(image).isNotNull();
        assertThat(image.getWidth()).isEqualTo(512);
        assertThat(image.getHeight()).isEqualTo(512);
    }

    private static void assertGreenDominant(int rgb) {
        Color color = new Color(rgb);
        assertThat(color.getGreen()).isGreaterThan(120);
        assertThat(color.getGreen()).isGreaterThan(color.getRed() + 30);
        assertThat(color.getGreen()).isGreaterThan(color.getBlue() + 30);
    }

    private static void assertPurpleDominant(int rgb) {
        Color color = new Color(rgb);
        assertThat(color.getRed()).isGreaterThan(80);
        assertThat(color.getBlue()).isGreaterThan(80);
        assertThat(color.getGreen()).isLessThan(60);
    }

    private static final class FakeImageProcessor implements ImageProcessor {

        private ProcessedPhoto result = processedPhoto(squareSourceBytes(512));
        private RuntimeException failure;
        private ImageProcessingInput receivedInput;

        @Override
        public ProcessedPhoto process(ImageProcessingInput input) {
            receivedInput = input;
            if (failure != null) {
                throw failure;
            }
            return result;
        }
    }
}
