package memory_map.backend.media.image;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class ImageProcessorContractTest {

    @Test
    void shouldReturnProcessedPhotoAtomically() {
        ImageProcessor processor = input -> new ProcessedPhoto(
                new ProcessedImage(new byte[] {1, 2, 3}),
                new ProcessedImage(new byte[] {4}),
                ImageProcessingPolicy.DEFAULT_OUTPUT_MIME_TYPE
        );

        ProcessedPhoto photo = processor.process(new ImageProcessingInput(
                new byte[] {9},
                "image/png"
        ));

        assertThat(photo.display().content()).containsExactly(1, 2, 3);
        assertThat(photo.thumbnail().content()).containsExactly(4);
        assertThat(photo.mimeType()).isEqualTo("image/jpeg");
    }
}
