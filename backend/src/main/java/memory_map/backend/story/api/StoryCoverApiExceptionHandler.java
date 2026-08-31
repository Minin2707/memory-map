package memory_map.backend.story.api;

import memory_map.backend.media.storage.StorageException;
import memory_map.backend.media.image.ImageProcessingException;
import memory_map.backend.media.image.InvalidImageException;
import memory_map.backend.story.application.StoryNotFoundException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.web.HttpMediaTypeNotSupportedException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;
import org.springframework.web.multipart.support.MissingServletRequestPartException;

import java.net.URI;

@RestControllerAdvice(assignableTypes = StoryCoverController.class)
public class StoryCoverApiExceptionHandler {

    private static final URI STORY_COVER_INSTANCE =
            URI.create("/api/v1/stories/cover");

    @ExceptionHandler(StoryNotFoundException.class)
    public ProblemDetail handleStoryCoverUnavailable() {
        ProblemDetail problemDetail = ProblemDetail.forStatusAndDetail(
                HttpStatus.NOT_FOUND,
                "Story cover could not be found"
        );
        problemDetail.setTitle("Not Found");
        problemDetail.setInstance(STORY_COVER_INSTANCE);

        return problemDetail;
    }

    @ExceptionHandler({
            InvalidStoryCoverRequestException.class,
            InvalidImageException.class,
            MethodArgumentTypeMismatchException.class,
            MissingServletRequestPartException.class,
            HttpMediaTypeNotSupportedException.class
    })
    public ProblemDetail handleInvalidStoryCoverRequest() {
        ProblemDetail problemDetail = ProblemDetail.forStatusAndDetail(
                HttpStatus.BAD_REQUEST,
                "Invalid story cover request"
        );
        problemDetail.setTitle("Bad Request");
        problemDetail.setInstance(STORY_COVER_INSTANCE);

        return problemDetail;
    }

    @ExceptionHandler(ImageProcessingException.class)
    public ProblemDetail handleStoryCoverProcessingFailure() {
        ProblemDetail problemDetail = ProblemDetail.forStatusAndDetail(
                HttpStatus.INTERNAL_SERVER_ERROR,
                "Story cover upload failed"
        );
        problemDetail.setTitle("Internal Server Error");
        problemDetail.setInstance(STORY_COVER_INSTANCE);

        return problemDetail;
    }

    @ExceptionHandler(StorageException.class)
    public ProblemDetail handleStoryCoverStorageFailure() {
        ProblemDetail problemDetail = ProblemDetail.forStatusAndDetail(
                HttpStatus.INTERNAL_SERVER_ERROR,
                "Story cover could not be streamed"
        );
        problemDetail.setTitle("Internal Server Error");
        problemDetail.setInstance(STORY_COVER_INSTANCE);

        return problemDetail;
    }
}
