package memory_map.backend.music.application;

import memory_map.backend.media.storage.StorageByteRange;

import java.util.Objects;

public final class StorySoundtrackAudioRange {

    private final Kind kind;
    private final long start;
    private final long endInclusive;
    private final long suffixLength;

    private StorySoundtrackAudioRange(
            Kind kind,
            long start,
            long endInclusive,
            long suffixLength
    ) {
        this.kind = Objects.requireNonNull(kind, "kind must not be null");
        this.start = start;
        this.endInclusive = endInclusive;
        this.suffixLength = suffixLength;

        validate();
    }

    public static StorySoundtrackAudioRange startEnd(
            long start,
            long endInclusive
    ) {
        return new StorySoundtrackAudioRange(
                Kind.START_END,
                start,
                endInclusive,
                0L
        );
    }

    public static StorySoundtrackAudioRange openEnded(long start) {
        return new StorySoundtrackAudioRange(
                Kind.OPEN_ENDED,
                start,
                0L,
                0L
        );
    }

    public static StorySoundtrackAudioRange suffix(long suffixLength) {
        return new StorySoundtrackAudioRange(
                Kind.SUFFIX,
                0L,
                0L,
                suffixLength
        );
    }

    public StorageByteRange normalize(long totalLength) {
        if (totalLength <= 0) {
            throw new IllegalArgumentException("totalLength must be positive");
        }

        return switch (kind) {
            case START_END -> normalizeStartEnd(totalLength);
            case OPEN_ENDED -> normalizeOpenEnded(totalLength);
            case SUFFIX -> normalizeSuffix(totalLength);
        };
    }

    public Kind kind() {
        return kind;
    }

    public long start() {
        return start;
    }

    public long endInclusive() {
        return endInclusive;
    }

    public long suffixLength() {
        return suffixLength;
    }

    @Override
    public boolean equals(Object other) {
        if (this == other) {
            return true;
        }

        if (!(other instanceof StorySoundtrackAudioRange range)) {
            return false;
        }

        return kind == range.kind
                && start == range.start
                && endInclusive == range.endInclusive
                && suffixLength == range.suffixLength;
    }

    @Override
    public int hashCode() {
        return Objects.hash(kind, start, endInclusive, suffixLength);
    }

    @Override
    public String toString() {
        return "StorySoundtrackAudioRange[kind=%s]".formatted(kind);
    }

    private StorageByteRange normalizeStartEnd(long totalLength) {
        if (start >= totalLength) {
            throw new InvalidStorySoundtrackAudioRangeException(totalLength);
        }

        long clampedEnd = Math.min(endInclusive, totalLength - 1L);

        return new StorageByteRange(
                start,
                clampedEnd - start + 1L
        );
    }

    private StorageByteRange normalizeOpenEnded(long totalLength) {
        if (start >= totalLength) {
            throw new InvalidStorySoundtrackAudioRangeException(totalLength);
        }

        return new StorageByteRange(start, totalLength - start);
    }

    private StorageByteRange normalizeSuffix(long totalLength) {
        if (suffixLength >= totalLength) {
            return new StorageByteRange(0L, totalLength);
        }

        return new StorageByteRange(
                totalLength - suffixLength,
                suffixLength
        );
    }

    private void validate() {
        switch (kind) {
            case START_END -> validateStartEnd();
            case OPEN_ENDED -> validateOpenEnded();
            case SUFFIX -> validateSuffix();
        }
    }

    private void validateStartEnd() {
        if (start < 0) {
            throw new IllegalArgumentException(
                    "start must not be negative"
            );
        }

        if (endInclusive < start) {
            throw new IllegalArgumentException(
                    "endInclusive must not be before start"
            );
        }
    }

    private void validateOpenEnded() {
        if (start < 0) {
            throw new IllegalArgumentException(
                    "start must not be negative"
            );
        }
    }

    private void validateSuffix() {
        if (suffixLength <= 0) {
            throw new IllegalArgumentException(
                    "suffixLength must be positive"
            );
        }
    }

    public enum Kind {
        START_END,
        OPEN_ENDED,
        SUFFIX
    }
}
