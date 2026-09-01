package memory_map.backend.story.application;

import java.io.InputStream;
import java.util.Objects;

public final class DownloadedStoryParticipantAvatar {

    private final InputStream content;
    private final long contentLength;
    private final String contentType;

    public DownloadedStoryParticipantAvatar(
            InputStream content,
            long contentLength,
            String contentType
    ) {
        this.content = Objects.requireNonNull(
                content,
                "content must not be null"
        );
        this.contentType = Objects.requireNonNull(
                contentType,
                "contentType must not be null"
        );

        if (contentLength <= 0) {
            throw new IllegalArgumentException("contentLength must be positive");
        }

        if (contentType.isBlank()) {
            throw new IllegalArgumentException("contentType must not be blank");
        }

        this.contentLength = contentLength;
    }

    public InputStream content() {
        return content;
    }

    public long contentLength() {
        return contentLength;
    }

    public String contentType() {
        return contentType;
    }

    @Override
    public String toString() {
        return "DownloadedStoryParticipantAvatar"
                + "[contentLength=%d, hasContentType=true]"
                        .formatted(contentLength);
    }
}
