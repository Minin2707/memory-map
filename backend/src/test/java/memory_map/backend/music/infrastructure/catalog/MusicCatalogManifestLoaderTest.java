package memory_map.backend.music.infrastructure.catalog;

import memory_map.backend.music.domain.MusicTrackStatus;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import tools.jackson.databind.json.JsonMapper;

import java.nio.file.Files;
import java.nio.file.Path;
import java.security.MessageDigest;
import java.util.HexFormat;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class MusicCatalogManifestLoaderTest {

    private static final UUID TRACK_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID OTHER_TRACK_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000002");
    private static final byte[] MP3_BYTES =
            new byte[] {(byte) 0xFF, (byte) 0xFB, 0x10, 0x00, 0x01};

    @TempDir
    Path tempDir;

    @Test
    void shouldLoadValidManifest() throws Exception {
        Path source = writeSourceFile("track.mp3", MP3_BYTES);
        Path manifest = writeManifest(manifestJson(
                TRACK_ID,
                "track.mp3",
                storageKey(TRACK_ID),
                "audio/mpeg",
                MP3_BYTES.length,
                sha256(MP3_BYTES),
                "ACTIVE",
                "approved"
        ));

        MusicCatalogManifest result = loader().load(manifest);

        assertThat(result.tracks()).hasSize(1);
        MusicCatalogManifestTrack track = result.tracks().getFirst();
        assertThat(track.id()).isEqualTo(TRACK_ID);
        assertThat(track.title()).isEqualTo("Calm Piano");
        assertThat(track.artist()).isEqualTo("Memory Story");
        assertThat(track.durationSeconds()).isEqualTo(270);
        assertThat(track.sortOrder()).isEqualTo(10);
        assertThat(track.sourceFile()).isEqualTo(source.toAbsolutePath());
        assertThat(track.storageKey()).isEqualTo(storageKey(TRACK_ID));
        assertThat(track.mimeType()).isEqualTo("audio/mpeg");
        assertThat(track.fileSize()).isEqualTo(MP3_BYTES.length);
        assertThat(track.sha256()).isEqualTo(sha256(MP3_BYTES));
        assertThat(track.desiredStatus()).isEqualTo(MusicTrackStatus.ACTIVE);
        assertThat(track.legalStatus())
                .isEqualTo(MusicCatalogLegalStatus.APPROVED);
    }

    @Test
    void shouldRejectDuplicateId() throws Exception {
        writeSourceFile("first.mp3", MP3_BYTES);
        writeSourceFile("second.mp3", MP3_BYTES);
        Path manifest = writeManifest("""
                {"tracks":[
                %s,
                %s
                ]}
                """.formatted(
                trackJson(TRACK_ID, "first.mp3", storageKey(TRACK_ID)),
                trackJson(TRACK_ID, "second.mp3", storageKey(TRACK_ID))
        ));

        assertThatThrownBy(() -> loader().load(manifest))
                .isInstanceOf(MusicCatalogImportException.class)
                .hasMessage("Music catalog manifest contains duplicate track id");
    }

    @Test
    void shouldRejectDuplicateStorageKey() throws Exception {
        writeSourceFile("first.mp3", MP3_BYTES);
        writeSourceFile("second.mp3", MP3_BYTES);
        Path manifest = writeManifest("""
                {"tracks":[
                %s,
                %s
                ]}
                """.formatted(
                trackJson(TRACK_ID, "first.mp3", storageKey(TRACK_ID)),
                trackJson(OTHER_TRACK_ID, "second.mp3", storageKey(TRACK_ID))
        ));

        assertThatThrownBy(() -> loader().load(manifest))
                .isInstanceOf(MusicCatalogImportException.class)
                .hasMessage("Music catalog manifest storage key does not match expected key");
    }

    @Test
    void shouldRejectInvalidShaFormat() throws Exception {
        writeSourceFile("track.mp3", MP3_BYTES);
        Path manifest = writeManifest(manifestJson(
                TRACK_ID,
                "track.mp3",
                storageKey(TRACK_ID),
                "audio/mpeg",
                MP3_BYTES.length,
                "not-a-sha",
                "ACTIVE",
                "approved"
        ));

        assertThatThrownBy(() -> loader().load(manifest))
                .isInstanceOf(MusicCatalogImportException.class)
                .hasMessage("Music catalog manifest contains invalid SHA-256");
    }

    @Test
    void shouldRejectMissingFile() throws Exception {
        Path manifest = writeManifest(manifestJson(
                TRACK_ID,
                "missing.mp3",
                storageKey(TRACK_ID),
                "audio/mpeg",
                MP3_BYTES.length,
                sha256(MP3_BYTES),
                "ACTIVE",
                "approved"
        ));

        assertThatThrownBy(() -> loader().load(manifest))
                .isInstanceOf(MusicCatalogImportException.class)
                .hasMessage("Music catalog source file was not found");
    }

    @Test
    void shouldRejectFileSizeMismatch() throws Exception {
        writeSourceFile("track.mp3", MP3_BYTES);
        Path manifest = writeManifest(manifestJson(
                TRACK_ID,
                "track.mp3",
                storageKey(TRACK_ID),
                "audio/mpeg",
                MP3_BYTES.length + 1L,
                sha256(MP3_BYTES),
                "ACTIVE",
                "approved"
        ));

        assertThatThrownBy(() -> loader().load(manifest))
                .isInstanceOf(MusicCatalogImportException.class)
                .hasMessage("Music catalog source file size does not match manifest");
    }

    @Test
    void shouldRejectShaMismatch() throws Exception {
        writeSourceFile("track.mp3", MP3_BYTES);
        Path manifest = writeManifest(manifestJson(
                TRACK_ID,
                "track.mp3",
                storageKey(TRACK_ID),
                "audio/mpeg",
                MP3_BYTES.length,
                "0000000000000000000000000000000000000000000000000000000000000000",
                "ACTIVE",
                "approved"
        ));

        assertThatThrownBy(() -> loader().load(manifest))
                .isInstanceOf(MusicCatalogImportException.class)
                .hasMessage("Music catalog source file SHA-256 does not match manifest");
    }

    @Test
    void shouldRejectUnsupportedMime() throws Exception {
        writeSourceFile("track.mp3", MP3_BYTES);
        Path manifest = writeManifest(manifestJson(
                TRACK_ID,
                "track.mp3",
                storageKey(TRACK_ID),
                "audio/wav",
                MP3_BYTES.length,
                sha256(MP3_BYTES),
                "ACTIVE",
                "approved"
        ));

        assertThatThrownBy(() -> loader().load(manifest))
                .isInstanceOf(MusicCatalogImportException.class)
                .hasMessage("Music catalog manifest contains unsupported MIME type");
    }

    @Test
    void shouldRejectActiveNonApprovedTrack() throws Exception {
        writeSourceFile("track.mp3", MP3_BYTES);
        Path manifest = writeManifest(manifestJson(
                TRACK_ID,
                "track.mp3",
                storageKey(TRACK_ID),
                "audio/mpeg",
                MP3_BYTES.length,
                sha256(MP3_BYTES),
                "ACTIVE",
                "hold"
        ));

        assertThatThrownBy(() -> loader().load(manifest))
                .isInstanceOf(MusicCatalogImportException.class)
                .hasMessage("Music catalog manifest cannot activate non-approved track");
    }

    private MusicCatalogManifestLoader loader() {
        return new MusicCatalogManifestLoader(
                JsonMapper.builder().build(),
                new MusicTrackStorageKeyFactory(),
                new MusicCatalogFileVerifier()
        );
    }

    private Path writeSourceFile(String name, byte[] content) throws Exception {
        Path path = tempDir.resolve(name);
        Files.write(path, content);
        return path.toAbsolutePath().normalize();
    }

    private Path writeManifest(String content) throws Exception {
        Path path = tempDir.resolve("manifest.json");
        Files.writeString(path, content);
        return path;
    }

    private static String manifestJson(
            UUID id,
            String sourceFile,
            String storageKey,
            String mimeType,
            long fileSize,
            String sha256,
            String desiredStatus,
            String legalStatus
    ) {
        return "{\"tracks\":[" + trackJson(
                id,
                sourceFile,
                storageKey,
                mimeType,
                fileSize,
                sha256,
                desiredStatus,
                legalStatus
        ) + "]}";
    }

    private static String trackJson(
            UUID id,
            String sourceFile,
            String storageKey
    ) {
        return trackJson(
                id,
                sourceFile,
                storageKey,
                "audio/mpeg",
                MP3_BYTES.length,
                sha256(MP3_BYTES),
                "ACTIVE",
                "approved"
        );
    }

    private static String trackJson(
            UUID id,
            String sourceFile,
            String storageKey,
            String mimeType,
            long fileSize,
            String sha256,
            String desiredStatus,
            String legalStatus
    ) {
        return """
                {
                  "id":"%s",
                  "title":"Calm Piano",
                  "artist":"Memory Story",
                  "durationSeconds":270,
                  "sortOrder":10,
                  "sourceFile":"%s",
                  "storageKey":"%s",
                  "mimeType":"%s",
                  "fileSize":%d,
                  "sha256":"%s",
                  "desiredStatus":"%s",
                  "legalStatus":"%s"
                }
                """.formatted(
                id,
                sourceFile,
                storageKey,
                mimeType,
                fileSize,
                sha256,
                desiredStatus,
                legalStatus
        );
    }

    private static String storageKey(UUID id) {
        return "music/tracks/" + id + "/audio.mp3";
    }

    private static String sha256(byte[] content) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            return HexFormat.of().formatHex(digest.digest(content));
        } catch (Exception exception) {
            throw new IllegalStateException(exception);
        }
    }
}
