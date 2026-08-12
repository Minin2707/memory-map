package memory_map.backend.media.image.jvm;

import memory_map.backend.media.image.ImageProcessingException;
import memory_map.backend.media.image.ImageProcessingInput;
import memory_map.backend.media.image.ImageProcessingPolicy;
import memory_map.backend.media.image.ImageProcessor;
import memory_map.backend.media.image.InvalidImageException;
import memory_map.backend.media.image.InvalidImageReason;
import memory_map.backend.media.image.ProcessedImage;
import memory_map.backend.media.image.ProcessedPhoto;

import javax.imageio.IIOImage;
import javax.imageio.ImageIO;
import javax.imageio.ImageReader;
import javax.imageio.ImageWriteParam;
import javax.imageio.ImageWriter;
import javax.imageio.stream.ImageInputStream;
import javax.imageio.stream.ImageOutputStream;
import java.awt.Color;
import java.awt.Graphics2D;
import java.awt.RenderingHints;
import java.awt.geom.AffineTransform;
import java.awt.image.AffineTransformOp;
import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.util.Iterator;
import java.util.Locale;
import java.util.Objects;

public final class JvmImageProcessor implements ImageProcessor {

    private static final String JPEG_FORMAT = "JPEG";

    private final ImageProcessingPolicy policy;

    public JvmImageProcessor(ImageProcessingPolicy policy) {
        this.policy = Objects.requireNonNull(policy, "policy must not be null");
    }

    @Override
    public ProcessedPhoto process(ImageProcessingInput input) {
        Objects.requireNonNull(input, "input must not be null");

        if (input.contentLength() == 0) {
            throw new InvalidImageException(InvalidImageReason.EMPTY);
        }

        if (input.contentLength() > policy.maxUploadBytes()) {
            throw new InvalidImageException(InvalidImageReason.TOO_LARGE);
        }

        byte[] content = input.content();
        ImageHeader header = readHeader(content);
        validateDeclaredContentType(input.declaredContentType(), header);
        validateDimensions(header);

        try {
            BufferedImage decoded = readImage(content);
            BufferedImage oriented = orient(toRgb(decoded), header.orientation());
            BufferedImage display = resizeWithin(
                    oriented,
                    policy.displayMaxLongSide()
            );
            BufferedImage thumbnail = resizeWithin(
                    display,
                    policy.thumbnailMaxLongSide()
            );

            return new ProcessedPhoto(
                    new ProcessedImage(encodeJpeg(display)),
                    new ProcessedImage(encodeJpeg(thumbnail)),
                    policy.outputMimeType()
            );
        } catch (InvalidImageException exception) {
            throw exception;
        } catch (Exception exception) {
            throw new ImageProcessingException(exception);
        }
    }

    private ImageHeader readHeader(byte[] content) {
        try (
                ImageInputStream imageInput =
                        ImageIO.createImageInputStream(
                                new ByteArrayInputStream(content)
                        )
        ) {
            if (imageInput == null) {
                throw new InvalidImageException(InvalidImageReason.INVALID_IMAGE);
            }

            Iterator<ImageReader> readers =
                    ImageIO.getImageReaders(imageInput);

            if (!readers.hasNext()) {
                throw new InvalidImageException(InvalidImageReason.INVALID_IMAGE);
            }

            ImageReader reader = readers.next();
            try {
                reader.setInput(imageInput, true, true);

                String actualContentType = contentTypeFor(reader.getFormatName());
                if (!policy.acceptedInputContentTypes()
                        .contains(actualContentType)) {
                    throw new InvalidImageException(
                            InvalidImageReason.UNSUPPORTED_TYPE
                    );
                }

                return new ImageHeader(
                        actualContentType,
                        reader.getWidth(0),
                        reader.getHeight(0),
                        actualContentType.equals("image/jpeg")
                                ? JpegExifOrientation.read(content)
                                : JpegExifOrientation.DEFAULT_ORIENTATION
                );
            } finally {
                reader.dispose();
            }
        } catch (InvalidImageException exception) {
            throw exception;
        } catch (IOException exception) {
            throw new InvalidImageException(InvalidImageReason.INVALID_IMAGE);
        }
    }

    private static String contentTypeFor(String formatName) {
        String normalized = formatName.toLowerCase(Locale.ROOT);

        return switch (normalized) {
            case "jpeg", "jpg" -> "image/jpeg";
            case "png" -> "image/png";
            default -> "application/octet-stream";
        };
    }

    private static void validateDeclaredContentType(
            String declaredContentType,
            ImageHeader header
    ) {
        if (
                declaredContentType != null
                        && !declaredContentType.equals(header.contentType())
        ) {
            throw new InvalidImageException(InvalidImageReason.MIME_MISMATCH);
        }
    }

    private void validateDimensions(ImageHeader header) {
        if (
                header.width() <= 0
                        || header.height() <= 0
                        || header.width() > policy.maxDimension()
                        || header.height() > policy.maxDimension()
        ) {
            throw new InvalidImageException(
                    InvalidImageReason.DIMENSIONS_EXCEEDED
            );
        }

        long pixels = (long) header.width() * (long) header.height();
        if (pixels > policy.maxDecodedPixels()) {
            throw new InvalidImageException(
                    InvalidImageReason.DIMENSIONS_EXCEEDED
            );
        }
    }

    private static BufferedImage readImage(byte[] content) throws IOException {
        BufferedImage decoded = ImageIO.read(new ByteArrayInputStream(content));

        if (decoded == null) {
            throw new InvalidImageException(InvalidImageReason.INVALID_IMAGE);
        }

        return decoded;
    }

    private static BufferedImage toRgb(BufferedImage source) {
        BufferedImage rgb = new BufferedImage(
                source.getWidth(),
                source.getHeight(),
                BufferedImage.TYPE_INT_RGB
        );
        Graphics2D graphics = rgb.createGraphics();
        try {
            graphics.setColor(Color.WHITE);
            graphics.fillRect(0, 0, rgb.getWidth(), rgb.getHeight());
            graphics.drawImage(source, 0, 0, null);
        } finally {
            graphics.dispose();
        }

        return rgb;
    }

    private static BufferedImage orient(
            BufferedImage image,
            int orientation
    ) {
        return switch (orientation) {
            case 2 -> transform(image, -1, 0, 0, 1, image.getWidth(), 0);
            case 3 -> transform(
                    image,
                    -1,
                    0,
                    0,
                    -1,
                    image.getWidth(),
                    image.getHeight()
            );
            case 4 -> transform(image, 1, 0, 0, -1, 0, image.getHeight());
            case 5 -> transform(image, 0, 1, 1, 0, 0, 0);
            case 6 -> transform(image, 0, 1, -1, 0, image.getHeight(), 0);
            case 7 -> transform(
                    image,
                    0,
                    -1,
                    -1,
                    0,
                    image.getHeight(),
                    image.getWidth()
            );
            case 8 -> transform(image, 0, -1, 1, 0, 0, image.getWidth());
            default -> image;
        };
    }

    private static BufferedImage transform(
            BufferedImage image,
            double m00,
            double m10,
            double m01,
            double m11,
            double m02,
            double m12
    ) {
        AffineTransform transform = new AffineTransform(
                m00,
                m10,
                m01,
                m11,
                m02,
                m12
        );
        AffineTransformOp operation = new AffineTransformOp(
                transform,
                AffineTransformOp.TYPE_BICUBIC
        );
        int width = Math.abs(m00) == 1.0
                ? image.getWidth()
                : image.getHeight();
        int height = Math.abs(m11) == 1.0
                ? image.getHeight()
                : image.getWidth();
        BufferedImage result = new BufferedImage(
                width,
                height,
                BufferedImage.TYPE_INT_RGB
        );

        return operation.filter(image, result);
    }

    private static BufferedImage resizeWithin(
            BufferedImage source,
            int maxLongSide
    ) {
        int longSide = Math.max(source.getWidth(), source.getHeight());
        if (longSide <= maxLongSide) {
            return source;
        }

        double scale = (double) maxLongSide / (double) longSide;
        int width = Math.max(1, (int) Math.round(source.getWidth() * scale));
        int height = Math.max(1, (int) Math.round(source.getHeight() * scale));

        BufferedImage resized = new BufferedImage(
                width,
                height,
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
            graphics.setRenderingHint(
                    RenderingHints.KEY_ANTIALIASING,
                    RenderingHints.VALUE_ANTIALIAS_ON
            );
            graphics.drawImage(source, 0, 0, width, height, null);
        } finally {
            graphics.dispose();
        }

        return resized;
    }

    private byte[] encodeJpeg(BufferedImage image) throws IOException {
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
            params.setCompressionQuality(
                    (float) policy.outputJpegQuality() / 100.0f
            );

            writer.write(null, new IIOImage(image, null, null), params);
            imageOutput.flush();

            return output.toByteArray();
        } finally {
            writer.dispose();
        }
    }

    private record ImageHeader(
            String contentType,
            int width,
            int height,
            int orientation
    ) {
    }
}
