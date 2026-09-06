package memory_map.backend.media.api;

import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.multipart.MultipartException;

import java.net.URI;
import java.util.regex.Pattern;

@RestControllerAdvice
public class MediaMultipartExceptionHandler {

    private static final String INVALID_PHOTO_REQUEST =
            "Invalid photo request";
    private static final String INVALID_AVATAR_REQUEST =
            "Invalid avatar request";
    private static final String INVALID_STORY_COVER_REQUEST =
            "Invalid story cover request";
    private static final String INVALID_MULTIPART_REQUEST =
            "Invalid multipart request";
    private static final URI MEDIA_INSTANCE =
            URI.create("/api/v1/memories/media");
    private static final URI AVATAR_INSTANCE =
            URI.create("/api/v1/me/avatar");
    private static final URI STORY_COVER_INSTANCE =
            URI.create("/api/v1/stories/cover");
    private static final URI MULTIPART_INSTANCE =
            URI.create("/api/v1/multipart");
    private static final String AVATAR_PATH = "/api/v1/me/avatar";
    private static final Pattern MEMORY_MEDIA_PATH = Pattern.compile(
            "^/api/v1/memories/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-"
                    + "[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-"
                    + "[0-9a-fA-F]{12}/media$"
    );
    private static final Pattern STORY_COVER_PATH = Pattern.compile(
            "^/api/v1/stories/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-"
                    + "[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-"
                    + "[0-9a-fA-F]{12}/cover$"
    );

    @ExceptionHandler(MultipartException.class)
    public ProblemDetail handleMultipartFailure(
            MultipartException exception,
            HttpServletRequest request
    ) {
        ErrorMapping mapping = mappingFor(request);
        ProblemDetail problemDetail = ProblemDetail.forStatusAndDetail(
                HttpStatus.BAD_REQUEST,
                mapping.detail()
        );
        problemDetail.setTitle("Bad Request");
        problemDetail.setInstance(mapping.instance());

        return problemDetail;
    }

    private static ErrorMapping mappingFor(HttpServletRequest request) {
        String path = requestPath(request);

        if (AVATAR_PATH.equals(path)) {
            return new ErrorMapping(INVALID_AVATAR_REQUEST, AVATAR_INSTANCE);
        }

        if (MEMORY_MEDIA_PATH.matcher(path).matches()) {
            return new ErrorMapping(INVALID_PHOTO_REQUEST, MEDIA_INSTANCE);
        }

        if (STORY_COVER_PATH.matcher(path).matches()) {
            return new ErrorMapping(
                    INVALID_STORY_COVER_REQUEST,
                    STORY_COVER_INSTANCE
            );
        }

        return new ErrorMapping(
                INVALID_MULTIPART_REQUEST,
                MULTIPART_INSTANCE
        );
    }

    private static String requestPath(HttpServletRequest request) {
        if (request == null) {
            return "";
        }

        String requestUri = request.getRequestURI();
        String contextPath = request.getContextPath();

        if (
                contextPath != null
                        && !contextPath.isBlank()
                        && requestUri != null
                        && requestUri.startsWith(contextPath)
        ) {
            return requestUri.substring(contextPath.length());
        }

        if (requestUri == null) {
            return "";
        }

        return requestUri;
    }

    private record ErrorMapping(String detail, URI instance) {
    }
}
