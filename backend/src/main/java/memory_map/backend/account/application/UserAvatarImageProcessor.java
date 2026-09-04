package memory_map.backend.account.application;

import memory_map.backend.media.image.ImageProcessingException;
import memory_map.backend.media.image.ImageProcessingInput;
import memory_map.backend.media.image.ImageProcessor;
import memory_map.backend.media.image.InvalidImageException;
import memory_map.backend.media.image.ProcessedPhoto;

import javax.imageio.IIOImage;
import javax.imageio.ImageIO;
import javax.imageio.ImageWriteParam;
import javax.imageio.ImageWriter;
import javax.imageio.stream.ImageOutputStream;
import java.awt.Graphics2D;
import java.awt.RenderingHints;
import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.util.Iterator;
import java.util.Objects;

public final class UserAvatarImageProcessor {

    static final int AVATAR_SIZE = 512;

    private static final String JPEG_FORMAT = "JPEG";
    private static final String JPEG_CONTENT_TYPE = "image/jpeg";
    private static final float JPEG_QUALITY = 0.85f;

    private final ImageProcessor imageProcessor;

    public UserAvatarImageProcessor(ImageProcessor imageProcessor) {
        this.imageProcessor = Objects.requireNonNull(
                imageProcessor,
                "imageProcessor must not be null"
        );
    }

    public ProcessedUserAvatar process(ImageProcessingInput input) {
        try {
            ProcessedPhoto processedPhoto = imageProcessor.process(input);
            BufferedImage normalized =
                    ImageIO.read(new ByteArrayInputStream(
                            processedPhoto.display().content()
                    ));
            if (normalized == null) {
                throw new ImageProcessingException();
            }

            BufferedImage cropped = centerCrop(normalized);
            BufferedImage resized = resize(cropped, AVATAR_SIZE);

            return new ProcessedUserAvatar(
                    encodeJpeg(resized),
                    JPEG_CONTENT_TYPE
            );
        } catch (InvalidImageException | ImageProcessingException exception) {
            throw new InvalidUserAvatarException(exception);
        } catch (IOException exception) {
            throw new InvalidUserAvatarException(exception);
        }
    }

    private static BufferedImage centerCrop(BufferedImage source) {
        int side = Math.min(source.getWidth(), source.getHeight());
        int x = (source.getWidth() - side) / 2;
        int y = (source.getHeight() - side) / 2;

        return source.getSubimage(x, y, side, side);
    }

    private static BufferedImage resize(BufferedImage source, int size) {
        if (source.getWidth() == size && source.getHeight() == size) {
            return source;
        }

        BufferedImage resized = new BufferedImage(
                size,
                size,
                BufferedImage.TYPE_INT_RGB
        );
        Graphics2D graphics = resized.createGraphics();
        try {
            graphics.setRenderingHint(
                    RenderingHints.KEY_INTERPOLATION,
                    RenderingHints.VALUE_INTERPOLATION_BICUBIC
            );
            graphics.setRenderingHint(
                    RenderingHints.KEY_RENDERING,
                    RenderingHints.VALUE_RENDER_QUALITY
            );
            graphics.drawImage(source, 0, 0, size, size, null);
        } finally {
            graphics.dispose();
        }

        return resized;
    }

    private static byte[] encodeJpeg(BufferedImage image) throws IOException {
        Iterator<ImageWriter> writers =
                ImageIO.getImageWritersByFormatName(JPEG_FORMAT);
        if (!writers.hasNext()) {
            throw new ImageProcessingException();
        }

        ImageWriter writer = writers.next();
        try (
                ByteArrayOutputStream output = new ByteArrayOutputStream();
                ImageOutputStream imageOutput =
                        ImageIO.createImageOutputStream(output)
        ) {
            writer.setOutput(imageOutput);
            ImageWriteParam params = writer.getDefaultWriteParam();
            params.setCompressionMode(ImageWriteParam.MODE_EXPLICIT);
            params.setCompressionQuality(JPEG_QUALITY);
            writer.write(null, new IIOImage(image, null, null), params);
            imageOutput.flush();

            return output.toByteArray();
        } finally {
            writer.dispose();
        }
    }
}
