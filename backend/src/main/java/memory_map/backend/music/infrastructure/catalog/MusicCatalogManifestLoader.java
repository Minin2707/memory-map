package memory_map.backend.music.infrastructure.catalog;

import memory_map.backend.music.domain.MusicTrackStatus;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Objects;
import java.util.Set;
import java.util.UUID;
import java.util.regex.Pattern;

public final class MusicCatalogManifestLoader {

    private static final Pattern SHA_256_PATTERN =
            Pattern.compile("^[0-9a-fA-F]{64}$");

    private final JsonMapper jsonMapper;
    private final MusicTrackStorageKeyFactory storageKeyFactory;
    private final MusicCatalogFileVerifier fileVerifier;

    public MusicCatalogManifestLoader(
            JsonMapper jsonMapper,
            MusicTrackStorageKeyFactory storageKeyFactory,
            MusicCatalogFileVerifier fileVerifier
    ) {
        this.jsonMapper = Objects.requireNonNull(
                jsonMapper,
                "jsonMapper must not be null"
        );
        this.storageKeyFactory = Objects.requireNonNull(
                storageKeyFactory,
                "storageKeyFactory must not be null"
        );
        this.fileVerifier = Objects.requireNonNull(
                fileVerifier,
                "fileVerifier must not be null"
        );
    }

    public MusicCatalogManifest load(Path manifestPath) {
        Objects.requireNonNull(
                manifestPath,
                "manifestPath must not be null"
        );

        if (!Files.isRegularFile(manifestPath)) {
            throw new MusicCatalogImportException(
                    "Music catalog manifest was not found"
            );
        }

        if (!Files.isReadable(manifestPath)) {
            throw new MusicCatalogImportException(
                    "Music catalog manifest is not readable"
            );
        }

        JsonNode root = readJson(manifestPath);

        if (!root.isObject()) {
            throw new MusicCatalogImportException(
                    "Music catalog manifest must be a JSON object"
            );
        }

        JsonNode tracksNode = root.get("tracks");

        if (tracksNode == null || !tracksNode.isArray()) {
            throw new MusicCatalogImportException(
                    "Music catalog manifest tracks must be an array"
            );
        }

        List<MusicCatalogManifestTrack> tracks = new ArrayList<>();
        Set<UUID> ids = new HashSet<>();
        Set<String> storageKeys = new HashSet<>();
        Path baseDirectory = manifestPath.toAbsolutePath()
                .normalize()
                .getParent();

        for (int index = 0; index < tracksNode.size(); index++) {
            MusicCatalogManifestTrack track = parseTrack(
                    tracksNode.get(index),
                    index,
                    baseDirectory
            );

            if (!ids.add(track.id())) {
                throw new MusicCatalogImportException(
                        "Music catalog manifest contains duplicate track id"
                );
            }

            if (!storageKeys.add(track.storageKey())) {
                throw new MusicCatalogImportException(
                        "Music catalog manifest contains duplicate storage key"
                );
            }

            tracks.add(track);
        }

        return new MusicCatalogManifest(tracks);
    }

    private JsonNode readJson(Path manifestPath) {
        try (InputStream input = Files.newInputStream(manifestPath)) {
            return jsonMapper.readTree(input);
        } catch (IOException exception) {
            throw new MusicCatalogImportException(
                    "Music catalog manifest could not be read",
                    exception
            );
        }
    }

    private MusicCatalogManifestTrack parseTrack(
            JsonNode node,
            int index,
            Path baseDirectory
    ) {
        if (node == null || !node.isObject()) {
            throw new MusicCatalogImportException(
                    "Music catalog manifest track must be an object"
            );
        }

        UUID id = uuidField(node, "id");
        String title = textField(node, "title");
        String artist = textField(node, "artist");
        int durationSeconds = intField(node, "durationSeconds");
        int sortOrder = intField(node, "sortOrder");
        String sourceFile = textField(node, "sourceFile");
        String storageKey = textField(node, "storageKey");
        String mimeType = textField(node, "mimeType");
        long fileSize = longField(node, "fileSize");
        String sha256 = textField(node, "sha256");
        MusicTrackStatus desiredStatus = statusField(node, "desiredStatus");
        MusicCatalogLegalStatus legalStatus =
                legalStatusField(node, "legalStatus");

        Path sourcePath = resolveSourceFile(baseDirectory, sourceFile);
        validateTrack(
                id,
                sourcePath,
                storageKey,
                mimeType,
                fileSize,
                sha256,
                desiredStatus,
                legalStatus,
                index
        );

        return new MusicCatalogManifestTrack(
                id,
                title,
                artist,
                durationSeconds,
                sortOrder,
                sourcePath,
                sourcePath.getFileName().toString(),
                storageKey,
                mimeType,
                fileSize,
                sha256.toLowerCase(Locale.ROOT),
                desiredStatus,
                legalStatus
        );
    }

    private void validateTrack(
            UUID id,
            Path sourceFile,
            String storageKey,
            String mimeType,
            long fileSize,
            String sha256,
            MusicTrackStatus desiredStatus,
            MusicCatalogLegalStatus legalStatus,
            int index
    ) {
        String expectedStorageKey = storageKeyFactory.storageKeyFor(id);
        if (!storageKey.equals(expectedStorageKey)) {
            throw new MusicCatalogImportException(
                    "Music catalog manifest storage key does not match expected key"
            );
        }

        if (!mimeType.equals(MusicCatalogFileVerifier.SUPPORTED_MIME_TYPE)) {
            throw new MusicCatalogImportException(
                    "Music catalog manifest contains unsupported MIME type"
            );
        }

        if (!SHA_256_PATTERN.matcher(sha256).matches()) {
            throw new MusicCatalogImportException(
                    "Music catalog manifest contains invalid SHA-256"
            );
        }

        if (legalStatus != MusicCatalogLegalStatus.APPROVED
                && desiredStatus == MusicTrackStatus.ACTIVE) {
            throw new MusicCatalogImportException(
                    "Music catalog manifest cannot activate non-approved track"
            );
        }

        if (!Files.isRegularFile(sourceFile)) {
            throw new MusicCatalogImportException(
                    "Music catalog source file was not found"
            );
        }

        if (!Files.isReadable(sourceFile)) {
            throw new MusicCatalogImportException(
                    "Music catalog source file is not readable"
            );
        }

        if (!fileVerifier.hasMp3Extension(sourceFile)) {
            throw new MusicCatalogImportException(
                    "Music catalog source file must use .mp3 extension"
            );
        }

        long actualFileSize = fileVerifier.fileSize(sourceFile);
        if (actualFileSize != fileSize) {
            throw new MusicCatalogImportException(
                    "Music catalog source file size does not match manifest"
            );
        }

        String actualSha256 = fileVerifier.sha256(sourceFile);
        if (!actualSha256.equalsIgnoreCase(sha256)) {
            throw new MusicCatalogImportException(
                    "Music catalog source file SHA-256 does not match manifest"
            );
        }

        if (!fileVerifier.hasBasicMp3Marker(sourceFile)) {
            throw new MusicCatalogImportException(
                    "Music catalog source file does not look like MP3"
            );
        }
    }

    private static Path resolveSourceFile(
            Path baseDirectory,
            String sourceFile
    ) {
        Path sourcePath = Path.of(sourceFile);

        if (!sourcePath.isAbsolute()) {
            sourcePath = baseDirectory.resolve(sourcePath);
        }

        return sourcePath.toAbsolutePath().normalize();
    }

    private static String textField(JsonNode node, String fieldName) {
        JsonNode value = node.get(fieldName);

        if (value == null || value.isNull()) {
            throw new MusicCatalogImportException(
                    fieldName + " is required"
            );
        }

        if (!value.isString()) {
            throw new MusicCatalogImportException(
                    fieldName + " must be a string"
            );
        }

        String text = value.asString();
        if (text.isBlank()) {
            throw new MusicCatalogImportException(
                    fieldName + " must not be blank"
            );
        }

        return text;
    }

    private static int intField(JsonNode node, String fieldName) {
        JsonNode value = node.get(fieldName);

        if (value == null || value.isNull()) {
            throw new MusicCatalogImportException(
                    fieldName + " is required"
            );
        }

        if (!value.isNumber()) {
            throw new MusicCatalogImportException(
                    fieldName + " must be a number"
            );
        }

        int number = value.asInt();
        if (fieldName.equals("durationSeconds") && number <= 0) {
            throw new MusicCatalogImportException(
                    "durationSeconds must be positive"
            );
        }
        if (fieldName.equals("sortOrder") && number < 0) {
            throw new MusicCatalogImportException(
                    "sortOrder must not be negative"
            );
        }

        return number;
    }

    private static long longField(JsonNode node, String fieldName) {
        JsonNode value = node.get(fieldName);

        if (value == null || value.isNull()) {
            throw new MusicCatalogImportException(
                    fieldName + " is required"
            );
        }

        if (!value.isNumber()) {
            throw new MusicCatalogImportException(
                    fieldName + " must be a number"
            );
        }

        long number = value.asLong();
        if (number <= 0) {
            throw new MusicCatalogImportException(
                    fieldName + " must be positive"
            );
        }

        return number;
    }

    private static UUID uuidField(JsonNode node, String fieldName) {
        try {
            return UUID.fromString(textField(node, fieldName));
        } catch (IllegalArgumentException exception) {
            throw new MusicCatalogImportException(
                    fieldName + " must be a UUID"
            );
        }
    }

    private static MusicTrackStatus statusField(
            JsonNode node,
            String fieldName
    ) {
        try {
            return MusicTrackStatus.valueOf(
                    textField(node, fieldName).toUpperCase(Locale.ROOT)
            );
        } catch (IllegalArgumentException exception) {
            throw new MusicCatalogImportException(
                    fieldName + " must be ACTIVE or DISABLED"
            );
        }
    }

    private static MusicCatalogLegalStatus legalStatusField(
            JsonNode node,
            String fieldName
    ) {
        try {
            return MusicCatalogLegalStatus.valueOf(
                    textField(node, fieldName).toUpperCase(Locale.ROOT)
            );
        } catch (IllegalArgumentException exception) {
            throw new MusicCatalogImportException(
                    fieldName + " must be approved, hold, or rejected"
            );
        }
    }
}
