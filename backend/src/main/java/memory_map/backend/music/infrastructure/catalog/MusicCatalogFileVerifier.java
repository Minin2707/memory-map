package memory_map.backend.music.infrastructure.catalog;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;
import java.util.Locale;
import java.util.Objects;

public final class MusicCatalogFileVerifier {

    public static final String SUPPORTED_MIME_TYPE = "audio/mpeg";
    private static final int BUFFER_SIZE = 8 * 1024;

    public long fileSize(Path path) {
        Objects.requireNonNull(path, "path must not be null");

        try {
            return Files.size(path);
        } catch (IOException exception) {
            throw new MusicCatalogImportException(
                    "Source file size could not be read",
                    exception
            );
        }
    }

    public String sha256(Path path) {
        Objects.requireNonNull(path, "path must not be null");

        MessageDigest digest = sha256Digest();
        byte[] buffer = new byte[BUFFER_SIZE];

        try (InputStream input = Files.newInputStream(path)) {
            int read;
            while ((read = input.read(buffer)) != -1) {
                digest.update(buffer, 0, read);
            }
        } catch (IOException exception) {
            throw new MusicCatalogImportException(
                    "Source file hash could not be computed",
                    exception
            );
        }

        return HexFormat.of().formatHex(digest.digest());
    }

    public String sha256(InputStream input) {
        Objects.requireNonNull(input, "input must not be null");

        MessageDigest digest = sha256Digest();
        byte[] buffer = new byte[BUFFER_SIZE];

        try {
            int read;
            while ((read = input.read(buffer)) != -1) {
                digest.update(buffer, 0, read);
            }
        } catch (IOException exception) {
            throw new MusicCatalogImportException(
                    "Storage object hash could not be computed",
                    exception
            );
        }

        return HexFormat.of().formatHex(digest.digest());
    }

    public boolean hasMp3Extension(Path path) {
        Objects.requireNonNull(path, "path must not be null");

        Path fileName = path.getFileName();
        return fileName != null
                && fileName.toString()
                .toLowerCase(Locale.ROOT)
                .endsWith(".mp3");
    }

    public boolean hasBasicMp3Marker(Path path) {
        Objects.requireNonNull(path, "path must not be null");

        try (InputStream input = Files.newInputStream(path)) {
            byte[] header = input.readNBytes(10);

            if (startsWithId3(header)) {
                long id3Size = synchsafeSize(header);
                if (id3Size < 0) {
                    return false;
                }

                input.skipNBytes(id3Size);
                byte[] frame = input.readNBytes(2);
                return startsWithMpegFrame(frame);
            }

            return startsWithMpegFrame(header);
        } catch (IOException exception) {
            throw new MusicCatalogImportException(
                    "Source file MP3 marker could not be read",
                    exception
            );
        }
    }

    private static MessageDigest sha256Digest() {
        try {
            return MessageDigest.getInstance("SHA-256");
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException(
                    "SHA-256 digest is not available",
                    exception
            );
        }
    }

    private static boolean startsWithId3(byte[] header) {
        return header.length >= 3
                && header[0] == 'I'
                && header[1] == 'D'
                && header[2] == '3';
    }

    private static boolean startsWithMpegFrame(byte[] bytes) {
        return bytes.length >= 2
                && (bytes[0] & 0xFF) == 0xFF
                && (bytes[1] & 0xE0) == 0xE0;
    }

    private static long synchsafeSize(byte[] header) {
        if (header.length < 10) {
            return -1L;
        }

        long size = 0L;
        for (int index = 6; index <= 9; index++) {
            int value = header[index] & 0xFF;
            if ((value & 0x80) != 0) {
                return -1L;
            }
            size = (size << 7) | value;
        }

        return size;
    }
}
