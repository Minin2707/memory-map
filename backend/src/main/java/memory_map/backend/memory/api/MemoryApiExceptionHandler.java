package memory_map.backend.memory.api;

import memory_map.backend.memory.application.MemoryCreationUnavailableException;
import memory_map.backend.memory.application.MemoryDeletionUnavailableException;
import memory_map.backend.memory.application.MemoryNotFoundException;
import memory_map.backend.memory.application.MemoryUpdateUnavailableException;
import memory_map.backend.story.application.StoryNotFoundException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;

import java.net.URI;

@RestControllerAdvice(assignableTypes = MemoryController.class)
public class MemoryApiExceptionHandler {

    private static final String MEMORY_COULD_NOT_BE_CREATED =
            "Memory could not be created";
    private static final String MEMORY_WAS_NOT_FOUND =
            "Memory was not found";
    private static final String MEMORY_COULD_NOT_BE_UPDATED =
            "Memory could not be updated";
    private static final String MEMORY_COULD_NOT_BE_DELETED =
            "Memory could not be deleted";
    private static final String STORY_WAS_NOT_FOUND =
            "Story was not found";
    private static final String INVALID_MEMORY_REQUEST =
            "Invalid memory request";
    private static final URI MEMORY_COULD_NOT_BE_CREATED_INSTANCE =
            URI.create("/api/v1/stories/memories");
    private static final URI MEMORY_NOT_FOUND_INSTANCE =
            URI.create("/api/v1/memories");
    private static final URI MEMORY_COULD_NOT_BE_UPDATED_INSTANCE =
            URI.create("/api/v1/memories");
    private static final URI MEMORY_COULD_NOT_BE_DELETED_INSTANCE =
            URI.create("/api/v1/memories");
    private static final URI STORY_NOT_FOUND_INSTANCE =
            URI.create("/api/v1/stories");

    @ExceptionHandler(MemoryCreationUnavailableException.class)
    public ProblemDetail handleMemoryCreationUnavailable() {
        ProblemDetail problemDetail = ProblemDetail.forStatusAndDetail(
                HttpStatus.NOT_FOUND,
                MEMORY_COULD_NOT_BE_CREATED
        );
        problemDetail.setTitle("Not Found");
        problemDetail.setInstance(MEMORY_COULD_NOT_BE_CREATED_INSTANCE);

        return problemDetail;
    }

    @ExceptionHandler(MemoryNotFoundException.class)
    public ProblemDetail handleMemoryNotFound() {
        ProblemDetail problemDetail = ProblemDetail.forStatusAndDetail(
                HttpStatus.NOT_FOUND,
                MEMORY_WAS_NOT_FOUND
        );
        problemDetail.setTitle("Not Found");
        problemDetail.setInstance(MEMORY_NOT_FOUND_INSTANCE);

        return problemDetail;
    }

    @ExceptionHandler(MemoryUpdateUnavailableException.class)
    public ProblemDetail handleMemoryUpdateUnavailable() {
        ProblemDetail problemDetail = ProblemDetail.forStatusAndDetail(
                HttpStatus.NOT_FOUND,
                MEMORY_COULD_NOT_BE_UPDATED
        );
        problemDetail.setTitle("Not Found");
        problemDetail.setInstance(MEMORY_COULD_NOT_BE_UPDATED_INSTANCE);

        return problemDetail;
    }

    @ExceptionHandler(MemoryDeletionUnavailableException.class)
    public ProblemDetail handleMemoryDeletionUnavailable() {
        ProblemDetail problemDetail = ProblemDetail.forStatusAndDetail(
                HttpStatus.NOT_FOUND,
                MEMORY_COULD_NOT_BE_DELETED
        );
        problemDetail.setTitle("Not Found");
        problemDetail.setInstance(MEMORY_COULD_NOT_BE_DELETED_INSTANCE);

        return problemDetail;
    }

    @ExceptionHandler(StoryNotFoundException.class)
    public ProblemDetail handleStoryNotFound() {
        ProblemDetail problemDetail = ProblemDetail.forStatusAndDetail(
                HttpStatus.NOT_FOUND,
                STORY_WAS_NOT_FOUND
        );
        problemDetail.setTitle("Not Found");
        problemDetail.setInstance(STORY_NOT_FOUND_INSTANCE);

        return problemDetail;
    }

    @ExceptionHandler({
            MethodArgumentNotValidException.class,
            HttpMessageNotReadableException.class,
            MethodArgumentTypeMismatchException.class
    })
    public ProblemDetail handleBadRequest() {
        ProblemDetail problemDetail = ProblemDetail.forStatusAndDetail(
                HttpStatus.BAD_REQUEST,
                INVALID_MEMORY_REQUEST
        );
        problemDetail.setTitle("Bad Request");
        problemDetail.setInstance(MEMORY_COULD_NOT_BE_CREATED_INSTANCE);

        return problemDetail;
    }
}
