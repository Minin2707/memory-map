package memory_map.backend.story.api;

import memory_map.backend.music.application.StorySoundtrackAudioRange;

final class StorySoundtrackRangeParser {

    private static final String BYTES_PREFIX = "bytes=";

    private StorySoundtrackRangeParser() {
    }

    static StorySoundtrackAudioRange parse(String headerValue) {
        if (headerValue == null) {
            return null;
        }

        String value = headerValue.trim();

        if (!value.startsWith(BYTES_PREFIX)) {
            throw new MalformedStorySoundtrackAudioRangeException();
        }

        String range = value.substring(BYTES_PREFIX.length());

        if (range.isEmpty() || range.contains(",")) {
            throw new MalformedStorySoundtrackAudioRangeException();
        }

        int separator = range.indexOf('-');

        if (separator < 0 || range.indexOf('-', separator + 1) >= 0) {
            throw new MalformedStorySoundtrackAudioRangeException();
        }

        String start = range.substring(0, separator);
        String end = range.substring(separator + 1);

        if (start.isEmpty() && end.isEmpty()) {
            throw new MalformedStorySoundtrackAudioRangeException();
        }

        if (start.isEmpty()) {
            return StorySoundtrackAudioRange.suffix(positiveLong(end));
        }

        long parsedStart = nonNegativeLong(start);

        if (end.isEmpty()) {
            return StorySoundtrackAudioRange.openEnded(parsedStart);
        }

        long parsedEnd = nonNegativeLong(end);

        if (parsedEnd < parsedStart) {
            throw new MalformedStorySoundtrackAudioRangeException();
        }

        return StorySoundtrackAudioRange.startEnd(parsedStart, parsedEnd);
    }

    private static long positiveLong(String value) {
        long parsed = nonNegativeLong(value);

        if (parsed == 0L) {
            throw new MalformedStorySoundtrackAudioRangeException();
        }

        return parsed;
    }

    private static long nonNegativeLong(String value) {
        if (value.isEmpty() || !value.chars().allMatch(Character::isDigit)) {
            throw new MalformedStorySoundtrackAudioRangeException();
        }

        try {
            return Long.parseLong(value);
        } catch (NumberFormatException exception) {
            throw new MalformedStorySoundtrackAudioRangeException();
        }
    }
}
