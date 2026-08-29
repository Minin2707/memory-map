package memory_map.backend.account.application;

import java.util.Arrays;
import java.util.Objects;

public final class ProcessedUserAvatar {

    private final byte[] content;
    private final String contentType;

    public ProcessedUserAvatar(byte[] content, String contentType) {
        Objects.requireNonNull(content, "content must not be null");
        this.contentType = Objects.requireNonNull(
                contentType,
                "contentType must not be null"
        );

        if (content.length == 0) {
            throw new IllegalArgumentException("content must not be empty");
        }

        if (contentType.isBlank()) {
            throw new IllegalArgumentException(
                    "contentType must not be blank"
            );
        }

        this.content = Arrays.copyOf(content, content.length);
    }

    public byte[] content() {
        return Arrays.copyOf(content, content.length);
    }

    public long contentLength() {
        return content.length;
    }

    public String contentType() {
        return contentType;
    }
}
