package memory_map.backend.account.application;

import java.io.InputStream;
import java.util.Objects;

public record DownloadedUserAvatar(

        InputStream content,

        long contentLength,

        String contentType

) {
    public DownloadedUserAvatar {
        Objects.requireNonNull(content, "content must not be null");
        Objects.requireNonNull(contentType, "contentType must not be null");

        if (contentLength <= 0) {
            throw new IllegalArgumentException(
                    "contentLength must be positive"
            );
        }

        if (contentType.isBlank()) {
            throw new IllegalArgumentException(
                    "contentType must not be blank"
            );
        }
    }
}
