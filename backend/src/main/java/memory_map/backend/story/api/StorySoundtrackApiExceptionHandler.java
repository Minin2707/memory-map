package memory_map.backend.story.api;

import memory_map.backend.media.storage.StorageException;
import memory_map.backend.media.storage.StorageObjectNotFoundException;
import memory_map.backend.music.application.InvalidStorySoundtrackAudioRangeException;
import memory_map.backend.music.application.StorySoundtrackAudioUnavailableException;
import memory_map.backend.music.application.StorySoundtrackUnavailableException;
import memory_map.backend.story.application.StoryNotFoundException;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;

import java.net.URI;

@RestControllerAdvice(assignableTypes = StorySoundtrackController.class)
public class StorySoundtrackApiExceptionHandler {

    private static final URI STORY_SOUNDTRACK_INSTANCE =
            URI.create("/api/v1/stories/soundtrack");

    @ExceptionHandler(StoryNotFoundException.class)
    public ProblemDetail handleStoryNotFound() {
        return notFound("Story was not found");
    }

    @ExceptionHandler(StorySoundtrackUnavailableException.class)
    public ProblemDetail handleStorySoundtrackUnavailable() {
        return notFound("Story soundtrack could not be updated");
    }

    @ExceptionHandler({
            StorySoundtrackAudioUnavailableException.class,
            StorageObjectNotFoundException.class
    })
    public ProblemDetail handleStorySoundtrackAudioUnavailable() {
        return notFound("Story soundtrack audio could not be found");
    }

    @ExceptionHandler(MalformedStorySoundtrackAudioRangeException.class)
    public ProblemDetail handleMalformedStorySoundtrackAudioRange() {
        ProblemDetail problemDetail = ProblemDetail.forStatusAndDetail(
                HttpStatus.BAD_REQUEST,
                "Story soundtrack audio range is invalid"
        );
        problemDetail.setTitle("Bad Request");
        problemDetail.setInstance(STORY_SOUNDTRACK_INSTANCE);

        return problemDetail;
    }

    @ExceptionHandler(InvalidStorySoundtrackAudioRangeException.class)
    public ResponseEntity<ProblemDetail>
    handleInvalidStorySoundtrackAudioRange(
            InvalidStorySoundtrackAudioRangeException exception
    ) {
        ProblemDetail problemDetail = ProblemDetail.forStatusAndDetail(
                HttpStatus.REQUESTED_RANGE_NOT_SATISFIABLE,
                "Story soundtrack audio range is not satisfiable"
        );
        problemDetail.setTitle("Range Not Satisfiable");
        problemDetail.setInstance(STORY_SOUNDTRACK_INSTANCE);

        return ResponseEntity
                .status(HttpStatus.REQUESTED_RANGE_NOT_SATISFIABLE)
                .header(
                        HttpHeaders.CONTENT_RANGE,
                        "bytes */%d".formatted(exception.totalLength())
                )
                .body(problemDetail);
    }

    @ExceptionHandler({
            MethodArgumentNotValidException.class,
            HttpMessageNotReadableException.class,
            MethodArgumentTypeMismatchException.class
    })
    public ProblemDetail handleInvalidStorySoundtrackRequest() {
        ProblemDetail problemDetail = ProblemDetail.forStatusAndDetail(
                HttpStatus.BAD_REQUEST,
                "Invalid story soundtrack request"
        );
        problemDetail.setTitle("Bad Request");
        problemDetail.setInstance(STORY_SOUNDTRACK_INSTANCE);

        return problemDetail;
    }

    @ExceptionHandler(IllegalStateException.class)
    public ProblemDetail handleStorySoundtrackFailure() {
        ProblemDetail problemDetail = ProblemDetail.forStatusAndDetail(
                HttpStatus.INTERNAL_SERVER_ERROR,
                "Story soundtrack could not be resolved"
        );
        problemDetail.setTitle("Internal Server Error");
        problemDetail.setInstance(STORY_SOUNDTRACK_INSTANCE);

        return problemDetail;
    }

    @ExceptionHandler(StorageException.class)
    public ProblemDetail handleStorySoundtrackAudioStorageFailure() {
        ProblemDetail problemDetail = ProblemDetail.forStatusAndDetail(
                HttpStatus.INTERNAL_SERVER_ERROR,
                "Story soundtrack audio could not be streamed"
        );
        problemDetail.setTitle("Internal Server Error");
        problemDetail.setInstance(STORY_SOUNDTRACK_INSTANCE);

        return problemDetail;
    }

    private static ProblemDetail notFound(String detail) {
        ProblemDetail problemDetail = ProblemDetail.forStatusAndDetail(
                HttpStatus.NOT_FOUND,
                detail
        );
        problemDetail.setTitle("Not Found");
        problemDetail.setInstance(STORY_SOUNDTRACK_INSTANCE);

        return problemDetail;
    }
}
