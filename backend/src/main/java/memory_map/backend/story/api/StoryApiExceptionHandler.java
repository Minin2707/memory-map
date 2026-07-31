package memory_map.backend.story.api;

import memory_map.backend.story.application.StoryNotFoundException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.net.URI;

@RestControllerAdvice(assignableTypes = StoryController.class)
public class StoryApiExceptionHandler {

    private static final String STORY_NOT_FOUND = "Story was not found";
    private static final URI STORY_NOT_FOUND_INSTANCE =
            URI.create("/api/v1/stories");

    @ExceptionHandler(StoryNotFoundException.class)
    public ProblemDetail handleStoryNotFound() {
        ProblemDetail problemDetail = ProblemDetail.forStatusAndDetail(
                HttpStatus.NOT_FOUND,
                STORY_NOT_FOUND
        );
        problemDetail.setTitle("Not Found");
        problemDetail.setInstance(STORY_NOT_FOUND_INSTANCE);

        return problemDetail;
    }
}
