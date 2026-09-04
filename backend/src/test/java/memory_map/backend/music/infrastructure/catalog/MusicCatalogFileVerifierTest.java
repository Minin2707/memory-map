package memory_map.backend.music.infrastructure.catalog;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class MusicCatalogFileVerifierTest {

    private static final byte[] ABC_BYTES =
            new byte[] {'a', 'b', 'c'};
    private static final String ABC_SHA256 =
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad";
    private static final byte[] MPEG_FRAME =
            new byte[] {(byte) 0xFF, (byte) 0xE0, 0x10, 0x00};

    @TempDir
    Path tempDir;

    @Test
    void shouldReturnExactFileSizeForExistingFile() throws Exception {
        Path file = writeFile("track.mp3", new byte[] {1, 2, 3, 4, 5});

        assertThat(verifier().fileSize(file)).isEqualTo(5L);
    }

    @Test
    void shouldRejectNullFileSizePath() {
        assertThatThrownBy(() -> verifier().fileSize(null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("path must not be null");
    }

    @Test
    void shouldWrapFileSizeReadFailure() {
        assertThatThrownBy(() -> verifier().fileSize(missingFile()))
                .isInstanceOf(MusicCatalogImportException.class)
                .hasMessage("Source file size could not be read")
                .hasCauseInstanceOf(IOException.class);
    }

    @Test
    void shouldComputeSha256ForExistingFile() throws Exception {
        Path file = writeFile("track.mp3", ABC_BYTES);

        assertThat(verifier().sha256(file)).isEqualTo(ABC_SHA256);
    }

    @Test
    void shouldRejectNullSha256Path() {
        assertThatThrownBy(() -> verifier().sha256((Path) null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("path must not be null");
    }

    @Test
    void shouldWrapSha256PathReadFailure() {
        assertThatThrownBy(() -> verifier().sha256(missingFile()))
                .isInstanceOf(MusicCatalogImportException.class)
                .hasMessage("Source file hash could not be computed")
                .hasCauseInstanceOf(IOException.class);
    }

    @Test
    void shouldComputeSha256ForInputStream() {
        InputStream input = new java.io.ByteArrayInputStream(ABC_BYTES);

        assertThat(verifier().sha256(input)).isEqualTo(ABC_SHA256);
    }

    @Test
    void shouldRejectNullSha256InputStream() {
        assertThatThrownBy(() -> verifier().sha256((InputStream) null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("input must not be null");
    }

    @Test
    void shouldWrapSha256InputStreamReadFailure() {
        assertThatThrownBy(() -> verifier().sha256(new ThrowingInputStream()))
                .isInstanceOf(MusicCatalogImportException.class)
                .hasMessage("Storage object hash could not be computed")
                .hasCauseInstanceOf(IOException.class);
    }

    @Test
    void shouldDetectMp3ExtensionCaseInsensitively() {
        MusicCatalogFileVerifier verifier = verifier();

        assertThat(verifier.hasMp3Extension(Path.of("track.mp3"))).isTrue();
        assertThat(verifier.hasMp3Extension(Path.of("track.MP3"))).isTrue();
        assertThat(verifier.hasMp3Extension(Path.of("track.Mp3"))).isTrue();
        assertThat(verifier.hasMp3Extension(Path.of("track.wav"))).isFalse();
        assertThat(verifier.hasMp3Extension(Path.of("track.mp3.backup")))
                .isFalse();
    }

    @Test
    void shouldRejectNullMp3ExtensionPath() {
        assertThatThrownBy(() -> verifier().hasMp3Extension(null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("path must not be null");
    }

    @Test
    void shouldAcceptDirectMpegFrameMarker() throws Exception {
        Path file = writeFile("direct.mp3", MPEG_FRAME);

        assertThat(verifier().hasBasicMp3Marker(file)).isTrue();
    }

    @Test
    void shouldRejectEmptyOrShortDirectHeader() throws Exception {
        assertThat(verifier().hasBasicMp3Marker(writeFile("empty.mp3")))
                .isFalse();
        assertThat(verifier().hasBasicMp3Marker(
                writeFile("short.mp3", new byte[] {(byte) 0xFF})
        )).isFalse();
    }

    @Test
    void shouldRejectNonMpegDirectHeader() throws Exception {
        Path file = writeFile("not-mpeg.mp3", new byte[] {0x00, 0x01, 0x02});

        assertThat(verifier().hasBasicMp3Marker(file)).isFalse();
    }

    @Test
    void shouldAcceptId3HeaderFollowedByMpegFrame() throws Exception {
        Path file = writeFile(
                "id3.mp3",
                id3HeaderWithPayloadSize(3),
                new byte[] {0x11, 0x22, 0x33},
                MPEG_FRAME
        );

        assertThat(verifier().hasBasicMp3Marker(file)).isTrue();
    }

    @Test
    void shouldRejectId3HeaderWithInvalidSynchsafeSize() throws Exception {
        byte[] header = id3HeaderWithPayloadSize(0);
        header[6] = (byte) 0x80;
        Path file = writeFile("invalid-id3-size.mp3", header, MPEG_FRAME);

        assertThat(verifier().hasBasicMp3Marker(file)).isFalse();
    }

    @Test
    void shouldRejectId3HeaderFollowedByNonMpegFrame() throws Exception {
        Path file = writeFile(
                "id3-non-mpeg.mp3",
                id3HeaderWithPayloadSize(2),
                new byte[] {0x11, 0x22},
                new byte[] {0x00, 0x00}
        );

        assertThat(verifier().hasBasicMp3Marker(file)).isFalse();
    }

    @Test
    void shouldRejectId3HeaderWithoutPostId3FrameBytes() throws Exception {
        Path file = writeFile(
                "id3-no-frame.mp3",
                id3HeaderWithPayloadSize(2),
                new byte[] {0x11, 0x22}
        );

        assertThat(verifier().hasBasicMp3Marker(file)).isFalse();
    }

    @Test
    void shouldWrapMp3MarkerReadFailure() {
        assertThatThrownBy(() -> verifier().hasBasicMp3Marker(missingFile()))
                .isInstanceOf(MusicCatalogImportException.class)
                .hasMessage("Source file MP3 marker could not be read")
                .hasCauseInstanceOf(IOException.class);
    }

    @Test
    void shouldRejectNullMp3MarkerPath() {
        assertThatThrownBy(() -> verifier().hasBasicMp3Marker(null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("path must not be null");
    }

    private Path writeFile(String fileName, byte[]... chunks)
            throws IOException {

        Path file = tempDir.resolve(fileName);
        try (var output = Files.newOutputStream(file)) {
            for (byte[] chunk : chunks) {
                output.write(chunk);
            }
        }
        return file;
    }

    private Path missingFile() {
        return tempDir.resolve("missing.mp3");
    }

    private static byte[] id3HeaderWithPayloadSize(int payloadSize) {
        byte[] header = new byte[10];
        header[0] = 'I';
        header[1] = 'D';
        header[2] = '3';
        header[3] = 3;
        header[6] = (byte) ((payloadSize >> 21) & 0x7F);
        header[7] = (byte) ((payloadSize >> 14) & 0x7F);
        header[8] = (byte) ((payloadSize >> 7) & 0x7F);
        header[9] = (byte) (payloadSize & 0x7F);
        return header;
    }

    private static MusicCatalogFileVerifier verifier() {
        return new MusicCatalogFileVerifier();
    }

    private static final class ThrowingInputStream extends InputStream {

        @Override
        public int read() throws IOException {
            throw new IOException("forced read failure");
        }

        @Override
        public int read(byte[] bytes, int offset, int length)
                throws IOException {

            throw new IOException("forced read failure");
        }
    }
}
