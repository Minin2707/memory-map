package memory_map.backend.music.infrastructure.catalog;

import memory_map.backend.media.storage.StorageKey;
import memory_map.backend.media.storage.StorageObjectNotFoundException;
import memory_map.backend.media.storage.StorageService;
import memory_map.backend.media.storage.StorageStreamWrite;
import memory_map.backend.media.storage.StoredObject;
import memory_map.backend.music.domain.MusicTrack;
import memory_map.backend.music.domain.MusicTrackStatus;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.time.Clock;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Objects;
import java.util.Optional;
import java.util.UUID;

public final class MusicCatalogImportService {

    private final MusicCatalogWriter writer;
    private final StorageService storageService;
    private final MusicCatalogFileVerifier fileVerifier;
    private final Clock clock;

    public MusicCatalogImportService(
            MusicCatalogWriter writer,
            StorageService storageService,
            MusicCatalogFileVerifier fileVerifier,
            Clock clock
    ) {
        this.writer = Objects.requireNonNull(
                writer,
                "writer must not be null"
        );
        this.storageService = Objects.requireNonNull(
                storageService,
                "storageService must not be null"
        );
        this.fileVerifier = Objects.requireNonNull(
                fileVerifier,
                "fileVerifier must not be null"
        );
        this.clock = Objects.requireNonNull(clock, "clock must not be null");
    }

    public MusicCatalogImportReport importCatalog(
            MusicCatalogManifest manifest,
            boolean dryRun
    ) {
        Objects.requireNonNull(manifest, "manifest must not be null");

        List<TrackPlan> plans = new ArrayList<>();
        List<MusicCatalogTrackImportResult> results = new ArrayList<>();

        for (MusicCatalogManifestTrack track : manifest.tracks()) {
            plans.add(planTrack(track));
        }

        if (dryRun) {
            for (TrackPlan plan : plans) {
                results.add(result(
                        plan,
                        plan.verification(),
                        "DRY_RUN"
                ));
            }

            return new MusicCatalogImportReport(true, results);
        }

        for (TrackPlan plan : plans) {
            StorageVerification finalVerification = applyTrack(
                    plan.track(),
                    plan.existing(),
                    plan.plannedStatus(),
                    plan.verification()
            );
            results.add(result(plan, finalVerification, "APPLIED"));
        }

        return new MusicCatalogImportReport(false, results);
    }

    private TrackPlan planTrack(
            MusicCatalogManifestTrack track
    ) {
        List<MusicCatalogImportAction> actions = new ArrayList<>();
        MusicTrackStatus plannedStatus = plannedStatus(track);

        Optional<UUID> storageOwner = writer.findTrackIdByStorageKey(
                track.storageKey()
        );
        if (storageOwner.isPresent() && !storageOwner.orElseThrow()
                .equals(track.id())) {
            add(actions, MusicCatalogImportAction.FAIL);
            throw new MusicCatalogImportException(
                    "Music catalog storage key belongs to another track"
            );
        }

        Optional<MusicTrack> existing = writer.findById(track.id());
        existing.ifPresent(current -> validateExistingTrack(current, track));

        StorageVerification verification = verifyStorage(track);
        if (verification.mismatch()) {
            add(actions, MusicCatalogImportAction.FAIL);
            throw new MusicCatalogImportException(
                    "Music catalog storage object does not match manifest"
            );
        }

        existing.ifPresent(current -> planCurrentTrackActions(
                current,
                track,
                plannedStatus,
                verification,
                actions
        ));

        if (existing.isEmpty()) {
            add(actions, MusicCatalogImportAction.CREATE);
        }

        if (verification.missing()) {
            add(actions, MusicCatalogImportAction.UPLOAD);
        }

        add(actions, MusicCatalogImportAction.VERIFY);

        if (existing.isEmpty()
                || statusAfterSafetyDisable(existing, verification)
                != plannedStatus) {
            addStatusAction(actions, plannedStatus);
        }

        if (actions.size() == 1
                && actions.contains(MusicCatalogImportAction.VERIFY)
                && verification.matching()) {
            actions.clear();
            add(actions, MusicCatalogImportAction.NO_OP);
        }

        return new TrackPlan(
                track,
                existing,
                plannedStatus,
                verification,
                actions
        );
    }

    private StorageVerification applyTrack(
            MusicCatalogManifestTrack track,
            Optional<MusicTrack> existing,
            MusicTrackStatus plannedStatus,
            StorageVerification verification
    ) {
        Instant currentTime = clock.instant();

        MusicTrackStatus currentStatus = existing
                .map(MusicTrack::status)
                .orElse(MusicTrackStatus.DISABLED);

        if (existing.isEmpty()) {
            writer.insertDisabled(disabledTrack(track, currentTime));
        } else if (currentStatus == MusicTrackStatus.ACTIVE
                && verification.missing()) {
            writer.updateStatus(
                    track.id(),
                    MusicTrackStatus.DISABLED,
                    currentTime
            );
            currentStatus = MusicTrackStatus.DISABLED;
        }

        if (verification.missing()) {
            uploadAndVerify(track);
            verification = verifyStorage(track);
            if (!verification.matching()) {
                cleanupCurrentRunObject(track);
                throw new MusicCatalogImportException(
                        "Music catalog uploaded object did not verify"
                );
            }
        }

        if (existing.isPresent()
                && metadataDiffers(existing.orElseThrow(), track)) {
            writer.updateMetadata(
                    track.id(),
                    track.title(),
                    track.artist(),
                    track.sortOrder(),
                    clock.instant()
            );
        }

        if (currentStatus != plannedStatus) {
            writer.updateStatus(
                    track.id(),
                    plannedStatus,
                    clock.instant()
            );
        }

        return verification;
    }

    private void uploadAndVerify(MusicCatalogManifestTrack track) {
        try (InputStream content = Files.newInputStream(track.sourceFile())) {
            storageService.store(new StorageStreamWrite(
                    new StorageKey(track.storageKey()),
                    content,
                    track.fileSize(),
                    track.mimeType()
            ));
        } catch (IOException exception) {
            throw new MusicCatalogImportException(
                    "Music catalog source file could not be uploaded",
                    exception
            );
        }
    }

    private void cleanupCurrentRunObject(MusicCatalogManifestTrack track) {
        try {
            storageService.delete(new StorageKey(track.storageKey()));
        } catch (RuntimeException exception) {
            throw new MusicCatalogImportException(
                    "Music catalog uploaded object failed verification and cleanup failed",
                    exception
            );
        }
    }

    private StorageVerification verifyStorage(
            MusicCatalogManifestTrack track
    ) {
        try {
            StoredObject storedObject = storageService.read(
                    new StorageKey(track.storageKey())
            );
            try (InputStream content = storedObject.content()) {
                if (storedObject.contentLength() != track.fileSize()) {
                    return StorageVerification.mismatched();
                }

                if (!storedObject.contentType().equals(track.mimeType())) {
                    return StorageVerification.mismatched();
                }

                String actualSha256 = fileVerifier.sha256(content);
                if (!actualSha256.equalsIgnoreCase(track.sha256())) {
                    return StorageVerification.mismatched();
                }

                return StorageVerification.matched();
            }
        } catch (StorageObjectNotFoundException exception) {
            return StorageVerification.missingVerification();
        } catch (IOException exception) {
            throw new MusicCatalogImportException(
                    "Music catalog storage object could not be closed",
                    exception
            );
        }
    }

    private static void validateExistingTrack(
            MusicTrack current,
            MusicCatalogManifestTrack track
    ) {
        if (!current.storageKey().equals(track.storageKey())) {
            throw new MusicCatalogImportException(
                    "Music catalog track storage key cannot be changed"
            );
        }

        if (!current.mimeType().equals(track.mimeType())) {
            throw new MusicCatalogImportException(
                    "Music catalog track MIME type cannot be changed"
            );
        }

        if (current.fileSize() != track.fileSize()) {
            throw new MusicCatalogImportException(
                    "Music catalog track file size cannot be changed"
            );
        }

        if (current.durationSeconds() != track.durationSeconds()) {
            throw new MusicCatalogImportException(
                    "Music catalog track duration cannot be changed"
            );
        }
    }

    private static void planCurrentTrackActions(
            MusicTrack current,
            MusicCatalogManifestTrack track,
            MusicTrackStatus plannedStatus,
            StorageVerification verification,
            List<MusicCatalogImportAction> actions
    ) {
        if (current.status() == MusicTrackStatus.ACTIVE
                && verification.missing()) {
            add(actions, MusicCatalogImportAction.DISABLE);
        }

        if (metadataDiffers(current, track)) {
            add(actions, MusicCatalogImportAction.UPDATE_METADATA);
        }
    }

    private static MusicTrackStatus statusAfterSafetyDisable(
            Optional<MusicTrack> existing,
            StorageVerification verification
    ) {
        if (existing.isPresent()
                && existing.orElseThrow().status() == MusicTrackStatus.ACTIVE
                && verification.missing()) {
            return MusicTrackStatus.DISABLED;
        }

        return existing
                .map(MusicTrack::status)
                .orElse(MusicTrackStatus.DISABLED);
    }

    private static boolean metadataDiffers(
            MusicTrack current,
            MusicCatalogManifestTrack track
    ) {
        return !current.title().equals(track.title())
                || !current.artist().equals(track.artist())
                || current.sortOrder() != track.sortOrder();
    }

    private static MusicTrack disabledTrack(
            MusicCatalogManifestTrack track,
            Instant currentTime
    ) {
        return new MusicTrack(
                track.id(),
                track.title(),
                track.artist(),
                track.durationSeconds(),
                MusicTrackStatus.DISABLED,
                track.sortOrder(),
                track.storageKey(),
                track.mimeType(),
                track.fileSize(),
                currentTime,
                currentTime
        );
    }

    private static MusicTrackStatus plannedStatus(
            MusicCatalogManifestTrack track
    ) {
        if (track.shouldBeActive()) {
            return MusicTrackStatus.ACTIVE;
        }

        return MusicTrackStatus.DISABLED;
    }

    private static void addStatusAction(
            List<MusicCatalogImportAction> actions,
            MusicTrackStatus status
    ) {
        if (status == MusicTrackStatus.ACTIVE) {
            add(actions, MusicCatalogImportAction.ACTIVATE);
            return;
        }

        add(actions, MusicCatalogImportAction.DISABLE);
    }

    private static void add(
            List<MusicCatalogImportAction> actions,
            MusicCatalogImportAction action
    ) {
        if (!actions.contains(action)) {
            actions.add(action);
        }
    }

    private static MusicCatalogTrackImportResult result(
            TrackPlan plan,
            StorageVerification verification,
            String result
    ) {
        return new MusicCatalogTrackImportResult(
                plan.track().id(),
                plan.track().title(),
                plan.plannedStatus(),
                plan.actions(),
                verification.description(),
                result
        );
    }

    private record TrackPlan(

            MusicCatalogManifestTrack track,

            Optional<MusicTrack> existing,

            MusicTrackStatus plannedStatus,

            StorageVerification verification,

            List<MusicCatalogImportAction> actions

    ) {
        private TrackPlan {
            actions = List.copyOf(actions);
        }
    }

    private record StorageVerification(

            String description

    ) {
        static StorageVerification matched() {
            return new StorageVerification("MATCHING");
        }

        static StorageVerification missingVerification() {
            return new StorageVerification("MISSING");
        }

        static StorageVerification mismatched() {
            return new StorageVerification("MISMATCH");
        }

        boolean matching() {
            return description.equals("MATCHING");
        }

        boolean missing() {
            return description.equals("MISSING");
        }

        boolean mismatch() {
            return description.equals("MISMATCH");
        }
    }
}
