package memory_map.backend.media.image;

public interface ImageProcessor {

    /**
     * Returns display and thumbnail together or fails without a partial result.
     */
    ProcessedPhoto process(ImageProcessingInput input);
}
