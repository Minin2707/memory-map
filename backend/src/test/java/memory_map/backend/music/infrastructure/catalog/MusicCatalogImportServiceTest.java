package memory_map.backend.music.infrastructure.catalog;

import memory_map.backend.media.storage.StorageByteRange;
import memory_map.backend.media.storage.StorageKey;
import memory_map.backend.media.storage.StorageObjectNotFoundException;
import memory_map.backend.media.storage.StorageObjectWrite;
import memory_map.backend.media.storage.StorageService;
import memory_map.backend.media.storage.StorageStreamWrite;
import memory_map.backend.media.storage.StoredObject;
import memory_map.backend.music.domain.MusicTrack;
import memory_map.backend.music.domain.MusicTrackStatus;
import memory_map.backend.music.repository.MusicTrackRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import java.io.ByteArrayInputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.MessageDigest;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class MusicCatalogImportServiceTest {

    private static final UUID TRACK_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID OTHER_TRACK_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000002");
    private static final Instant NOW =
            Instant.parse("2026-01-01T10:00:00Z");
    private static final byte[] MP3_BYTES =
            new byte[] {(byte) 0xFF, (byte) 0xFB, 0x10, 0x00, 0x01};
    private static final byte[] OTHER_BYTES =
            new byte[] {(byte) 0xFF, (byte) 0xFB, 0x11, 0x00, 0x02};

    @TempDir
    Path tempDir;

    @Test
    void shouldImportNewTrackThroughDisabledUploadVerifyActiveLifecycle()
            throws Exception {

        TestContext context = testContext();
        MusicCatalogManifestTrack track = track(
                MusicTrackStatus.ACTIVE,
                MusicCatalogLegalStatus.APPROVED
        );

        MusicCatalogImportReport report =
                context.service().importCatalog(manifest(track), false);

        MusicTrack stored = context.writer().tracks().get(TRACK_ID);
        assertThat(stored.status()).isEqualTo(MusicTrackStatus.ACTIVE);
        assertThat(stored.createdAt()).isEqualTo(NOW);
        assertThat(stored.updatedAt()).isEqualTo(NOW);
        assertThat(context.storage().storedBytes(track.storageKey()))
                .containsExactly(MP3_BYTES);
        assertThat(context.writer().events()).containsExactly(
                "find storage key",
                "find id",
                "insert DISABLED",
                "update status ACTIVE"
        );
        assertThat(report.tracks().getFirst().actions()).containsExactly(
                MusicCatalogImportAction.CREATE,
                MusicCatalogImportAction.UPLOAD,
                MusicCatalogImportAction.VERIFY,
                MusicCatalogImportAction.ACTIVATE
        );
    }

    @Test
    void shouldKeepDesiredDisabledTrackDisabled() throws Exception {
        TestContext context = testContext();
        MusicCatalogManifestTrack track = track(
                MusicTrackStatus.DISABLED,
                MusicCatalogLegalStatus.APPROVED
        );

        context.service().importCatalog(manifest(track), false);

        assertThat(context.writer().tracks().get(TRACK_ID).status())
                .isEqualTo(MusicTrackStatus.DISABLED);
        assertThat(context.writer().events()).containsExactly(
                "find storage key",
                "find id",
                "insert DISABLED"
        );
    }

    @Test
    void shouldPerformZeroWritesDuringDryRun() throws Exception {
        TestContext context = testContext();
        MusicCatalogManifestTrack track = track(
                MusicTrackStatus.ACTIVE,
                MusicCatalogLegalStatus.APPROVED
        );

        MusicCatalogImportReport report =
                context.service().importCatalog(manifest(track), true);

        assertThat(context.writer().tracks()).isEmpty();
        assertThat(context.storage().storeCount()).isZero();
        assertThat(report.tracks().getFirst().actions()).containsExactly(
                MusicCatalogImportAction.CREATE,
                MusicCatalogImportAction.UPLOAD,
                MusicCatalogImportAction.VERIFY,
                MusicCatalogImportAction.ACTIVATE
        );
        assertThat(report.tracks().getFirst().result()).isEqualTo("DRY_RUN");
    }

    @Test
    void shouldNoOpWhenExistingTrackAndObjectMatch() throws Exception {
        MusicCatalogManifestTrack track = track(
                MusicTrackStatus.ACTIVE,
                MusicCatalogLegalStatus.APPROVED
        );
        TestContext context = testContext();
        context.writer().put(activeTrack(track));
        context.storage().put(track, MP3_BYTES);

        MusicCatalogImportReport report =
                context.service().importCatalog(manifest(track), false);

        assertThat(context.writer().updateCount()).isZero();
        assertThat(context.storage().storeCount()).isZero();
        assertThat(report.tracks().getFirst().actions()).containsExactly(
                MusicCatalogImportAction.NO_OP
        );
    }

    @Test
    void shouldRepairMissingObjectForExistingDisabledTrack() throws Exception {
        MusicCatalogManifestTrack track = track(
                MusicTrackStatus.ACTIVE,
                MusicCatalogLegalStatus.APPROVED
        );
        TestContext context = testContext();
        context.writer().put(disabledTrack(track));

        MusicCatalogImportReport report =
                context.service().importCatalog(manifest(track), false);

        assertThat(context.storage().storedBytes(track.storageKey()))
                .containsExactly(MP3_BYTES);
        assertThat(context.writer().tracks().get(TRACK_ID).status())
                .isEqualTo(MusicTrackStatus.ACTIVE);
        assertThat(report.tracks().getFirst().actions()).containsExactly(
                MusicCatalogImportAction.UPLOAD,
                MusicCatalogImportAction.VERIFY,
                MusicCatalogImportAction.ACTIVATE
        );
        assertThat(context.writer().events()).containsExactly(
                "find storage key",
                "find id",
                "update status ACTIVE"
        );
    }

    @Test
    void shouldRepairMissingObjectForExistingActiveTrackThroughDisabledSafety()
            throws Exception {

        MusicCatalogManifestTrack track = track(
                MusicTrackStatus.ACTIVE,
                MusicCatalogLegalStatus.APPROVED
        );
        TestContext context = testContext();
        context.writer().put(activeTrack(track));

        MusicCatalogImportReport report =
                context.service().importCatalog(manifest(track), false);

        assertThat(context.storage().storedBytes(track.storageKey()))
                .containsExactly(MP3_BYTES);
        assertThat(context.writer().tracks().get(TRACK_ID).status())
                .isEqualTo(MusicTrackStatus.ACTIVE);
        assertThat(report.tracks().getFirst().actions()).containsExactly(
                MusicCatalogImportAction.DISABLE,
                MusicCatalogImportAction.UPLOAD,
                MusicCatalogImportAction.VERIFY,
                MusicCatalogImportAction.ACTIVATE
        );
        assertThat(context.writer().events()).containsExactly(
                "find storage key",
                "find id",
                "update status DISABLED",
                "update status ACTIVE"
        );
    }

    @Test
    void shouldRecoverWhenObjectExistsButDbRowIsMissing() throws Exception {
        MusicCatalogManifestTrack track = track(
                MusicTrackStatus.ACTIVE,
                MusicCatalogLegalStatus.APPROVED
        );
        TestContext context = testContext();
        context.storage().put(track, MP3_BYTES);

        context.service().importCatalog(manifest(track), false);

        assertThat(context.storage().storeCount()).isZero();
        assertThat(context.writer().tracks().get(TRACK_ID).status())
                .isEqualTo(MusicTrackStatus.ACTIVE);
        assertThat(context.writer().events()).containsExactly(
                "find storage key",
                "find id",
                "insert DISABLED",
                "update status ACTIVE"
        );
    }

    @Test
    void shouldFailWhenObjectContentDiffersAndNotOverwrite()
            throws Exception {

        MusicCatalogManifestTrack track = track(
                MusicTrackStatus.ACTIVE,
                MusicCatalogLegalStatus.APPROVED
        );
        TestContext context = testContext();
        context.storage().put(track, OTHER_BYTES);

        assertThatThrownBy(() -> context.service().importCatalog(
                manifest(track),
                false
        )).isInstanceOf(MusicCatalogImportException.class)
                .hasMessage("Music catalog storage object does not match manifest");

        assertThat(context.storage().storedBytes(track.storageKey()))
                .containsExactly(OTHER_BYTES);
        assertThat(context.storage().storeCount()).isZero();
        assertThat(context.writer().tracks()).isEmpty();
    }

    @Test
    void shouldLeaveDisabledRowWhenUploadFails() throws Exception {
        MusicCatalogManifestTrack track = track(
                MusicTrackStatus.ACTIVE,
                MusicCatalogLegalStatus.APPROVED
        );
        TestContext context = testContext();
        context.storage().failStore(true);

        assertThatThrownBy(() -> context.service().importCatalog(
                manifest(track),
                false
        )).isInstanceOf(RuntimeException.class);

        assertThat(context.writer().tracks().get(TRACK_ID).status())
                .isEqualTo(MusicTrackStatus.DISABLED);
    }

    @Test
    void shouldLeaveObjectAndDisabledRowWhenActivationFails()
            throws Exception {

        MusicCatalogManifestTrack track = track(
                MusicTrackStatus.ACTIVE,
                MusicCatalogLegalStatus.APPROVED
        );
        TestContext context = testContext();
        context.writer().failActivation(true);

        assertThatThrownBy(() -> context.service().importCatalog(
                manifest(track),
                false
        )).isInstanceOf(RuntimeException.class)
                .hasMessage("activation failed");

        assertThat(context.storage().storedBytes(track.storageKey()))
                .containsExactly(MP3_BYTES);
        assertThat(context.writer().tracks().get(TRACK_ID).status())
                .isEqualTo(MusicTrackStatus.DISABLED);
    }

    @Test
    void shouldUpdateMetadataWithoutReuploadingBinary() throws Exception {
        MusicCatalogManifestTrack track = track(
                MusicTrackStatus.ACTIVE,
                MusicCatalogLegalStatus.APPROVED,
                "Updated Title",
                "Updated Artist",
                99
        );
        TestContext context = testContext();
        context.writer().put(new MusicTrack(
                track.id(),
                "Old Title",
                "Old Artist",
                track.durationSeconds(),
                MusicTrackStatus.ACTIVE,
                1,
                track.storageKey(),
                track.mimeType(),
                track.fileSize(),
                NOW,
                NOW
        ));
        context.storage().put(track, MP3_BYTES);

        context.service().importCatalog(manifest(track), false);

        MusicTrack result = context.writer().tracks().get(TRACK_ID);
        assertThat(result.title()).isEqualTo("Updated Title");
        assertThat(result.artist()).isEqualTo("Updated Artist");
        assertThat(result.sortOrder()).isEqualTo(99);
        assertThat(context.storage().storeCount()).isZero();
    }

    @Test
    void shouldDisableActiveTrack() throws Exception {
        MusicCatalogManifestTrack track = track(
                MusicTrackStatus.DISABLED,
                MusicCatalogLegalStatus.APPROVED
        );
        TestContext context = testContext();
        context.writer().put(activeTrack(track));
        context.storage().put(track, MP3_BYTES);

        context.service().importCatalog(manifest(track), false);

        assertThat(context.writer().tracks().get(TRACK_ID).status())
                .isEqualTo(MusicTrackStatus.DISABLED);
    }

    @Test
    void shouldFailWhenStorageKeyBelongsToAnotherTrack() throws Exception {
        MusicCatalogManifestTrack track = track(
                MusicTrackStatus.ACTIVE,
                MusicCatalogLegalStatus.APPROVED
        );
        TestContext context = testContext();
        context.writer().storageKeyOwner(track.storageKey(), OTHER_TRACK_ID);

        assertThatThrownBy(() -> context.service().importCatalog(
                manifest(track),
                false
        )).isInstanceOf(MusicCatalogImportException.class)
                .hasMessage("Music catalog storage key belongs to another track");
    }

    @Test
    void shouldKeepRuntimeMusicTrackRepositoryReadOnly() {
        assertThat(Arrays.stream(MusicTrackRepository.class.getDeclaredMethods())
                .map(method -> method.getName())
                .toList())
                .containsExactlyInAnyOrder("findById", "findActive");
    }

    private TestContext testContext() {
        FakeMusicCatalogWriter writer = new FakeMusicCatalogWriter();
        FakeStorageService storage = new FakeStorageService();
        MusicCatalogImportService service = new MusicCatalogImportService(
                writer,
                storage,
                new MusicCatalogFileVerifier(),
                Clock.fixed(NOW, ZoneOffset.UTC)
        );

        return new TestContext(service, writer, storage);
    }

    private MusicCatalogManifest manifest(MusicCatalogManifestTrack track) {
        return new MusicCatalogManifest(List.of(track));
    }

    private MusicCatalogManifestTrack track(
            MusicTrackStatus desiredStatus,
            MusicCatalogLegalStatus legalStatus
    ) throws Exception {
        return track(
                desiredStatus,
                legalStatus,
                "Calm Piano",
                "Memory Story",
                10
        );
    }

    private MusicCatalogManifestTrack track(
            MusicTrackStatus desiredStatus,
            MusicCatalogLegalStatus legalStatus,
            String title,
            String artist,
            int sortOrder
    ) throws Exception {
        Path source = tempDir.resolve("track.mp3");
        Files.write(source, MP3_BYTES);

        return new MusicCatalogManifestTrack(
                TRACK_ID,
                title,
                artist,
                270,
                sortOrder,
                source,
                "track.mp3",
                "music/tracks/" + TRACK_ID + "/audio.mp3",
                "audio/mpeg",
                MP3_BYTES.length,
                sha256(MP3_BYTES),
                desiredStatus,
                legalStatus
        );
    }

    private static MusicTrack activeTrack(MusicCatalogManifestTrack track) {
        return trackWithStatus(track, MusicTrackStatus.ACTIVE);
    }

    private static MusicTrack disabledTrack(MusicCatalogManifestTrack track) {
        return trackWithStatus(track, MusicTrackStatus.DISABLED);
    }

    private static MusicTrack trackWithStatus(
            MusicCatalogManifestTrack track,
            MusicTrackStatus status
    ) {
        return new MusicTrack(
                track.id(),
                track.title(),
                track.artist(),
                track.durationSeconds(),
                status,
                track.sortOrder(),
                track.storageKey(),
                track.mimeType(),
                track.fileSize(),
                NOW,
                NOW
        );
    }

    private static String sha256(byte[] content) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            return java.util.HexFormat.of().formatHex(digest.digest(content));
        } catch (Exception exception) {
            throw new IllegalStateException(exception);
        }
    }

    private record TestContext(

            MusicCatalogImportService service,

            FakeMusicCatalogWriter writer,

            FakeStorageService storage

    ) {
    }

    private static final class FakeMusicCatalogWriter
            implements MusicCatalogWriter {

        private final Map<UUID, MusicTrack> tracks = new HashMap<>();
        private final Map<String, UUID> storageKeyOwners = new HashMap<>();
        private final List<String> events = new java.util.ArrayList<>();
        private boolean failActivation;
        private int updateCount;

        @Override
        public Optional<MusicTrack> findById(UUID id) {
            events.add("find id");
            return Optional.ofNullable(tracks.get(id));
        }

        @Override
        public Optional<UUID> findTrackIdByStorageKey(String storageKey) {
            events.add("find storage key");
            return Optional.ofNullable(storageKeyOwners.get(storageKey));
        }

        @Override
        public void insertDisabled(MusicTrack musicTrack) {
            events.add("insert DISABLED");
            tracks.put(musicTrack.id(), musicTrack);
            storageKeyOwners.put(musicTrack.storageKey(), musicTrack.id());
        }

        @Override
        public void updateMetadata(
                UUID id,
                String title,
                String artist,
                int sortOrder,
                Instant updatedAt
        ) {
            events.add("update metadata");
            updateCount++;
            MusicTrack current = tracks.get(id);
            tracks.put(id, new MusicTrack(
                    current.id(),
                    title,
                    artist,
                    current.durationSeconds(),
                    current.status(),
                    sortOrder,
                    current.storageKey(),
                    current.mimeType(),
                    current.fileSize(),
                    current.createdAt(),
                    updatedAt
            ));
        }

        @Override
        public void updateStatus(
                UUID id,
                MusicTrackStatus status,
                Instant updatedAt
        ) {
            events.add("update status " + status);
            updateCount++;

            if (failActivation && status == MusicTrackStatus.ACTIVE) {
                throw new RuntimeException("activation failed");
            }

            MusicTrack current = tracks.get(id);
            tracks.put(id, new MusicTrack(
                    current.id(),
                    current.title(),
                    current.artist(),
                    current.durationSeconds(),
                    status,
                    current.sortOrder(),
                    current.storageKey(),
                    current.mimeType(),
                    current.fileSize(),
                    current.createdAt(),
                    updatedAt
            ));
        }

        void put(MusicTrack musicTrack) {
            tracks.put(musicTrack.id(), musicTrack);
            storageKeyOwners.put(musicTrack.storageKey(), musicTrack.id());
        }

        void storageKeyOwner(String storageKey, UUID id) {
            storageKeyOwners.put(storageKey, id);
        }

        void failActivation(boolean failActivation) {
            this.failActivation = failActivation;
        }

        Map<UUID, MusicTrack> tracks() {
            return tracks;
        }

        List<String> events() {
            return events;
        }

        int updateCount() {
            return updateCount;
        }
    }

    private static final class FakeStorageService implements StorageService {

        private final Map<String, StoredContent> objects = new HashMap<>();
        private boolean failStore;
        private int storeCount;

        @Override
        public void store(StorageObjectWrite object) {
            throw new UnsupportedOperationException();
        }

        @Override
        public void store(StorageStreamWrite object) {
            storeCount++;

            if (failStore) {
                throw new RuntimeException("store failed");
            }

            try {
                objects.put(
                        object.storageKey().value(),
                        new StoredContent(
                                object.content().readAllBytes(),
                                object.contentType()
                        )
                );
            } catch (Exception exception) {
                throw new RuntimeException(exception);
            }
        }

        @Override
        public StoredObject read(StorageKey storageKey) {
            StoredContent content = objects.get(storageKey.value());
            if (content == null) {
                throw new StorageObjectNotFoundException();
            }

            return new StoredObject(
                    new ByteArrayInputStream(content.content()),
                    content.content().length,
                    content.contentType()
            );
        }

        @Override
        public StoredObject readRange(
                StorageKey storageKey,
                StorageByteRange range
        ) {
            throw new UnsupportedOperationException();
        }

        @Override
        public void delete(StorageKey storageKey) {
            objects.remove(storageKey.value());
        }

        void put(MusicCatalogManifestTrack track, byte[] bytes) {
            objects.put(
                    track.storageKey(),
                    new StoredContent(bytes, track.mimeType())
            );
        }

        byte[] storedBytes(String storageKey) {
            return objects.get(storageKey).content();
        }

        void failStore(boolean failStore) {
            this.failStore = failStore;
        }

        int storeCount() {
            return storeCount;
        }
    }

    private record StoredContent(

            byte[] content,

            String contentType

    ) {
    }
}
