package memory_map.backend.media.api;

import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.multipart.MultipartException;

import java.net.URI;

@RestControllerAdvice
public class MediaMultipartExceptionHandler {

    private static final String INVALID_PHOTO_REQUEST =
            "Invalid photo request";
    private static final URI MEDIA_INSTANCE =
            URI.create("/api/v1/memories/media");

    @ExceptionHandler(MultipartException.class)
    public ProblemDetail handleMultipartFailure() {
        ProblemDetail problemDetail = ProblemDetail.forStatusAndDetail(
                HttpStatus.BAD_REQUEST,
                INVALID_PHOTO_REQUEST
        );
        problemDetail.setTitle("Bad Request");
        problemDetail.setInstance(MEDIA_INSTANCE);

        return problemDetail;
    }
}
