package memory_map.backend.media.image;

import org.junit.jupiter.api.Test;

import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class ImageProcessingPolicyTest {

    @Test
    void shouldProvideMvpDefaults() {
        ImageProcessingPolicy policy = ImageProcessingPolicy.mvpDefaults();

        assertThat(policy.maxUploadBytes()).isEqualTo(5L * 1024L * 1024L);
        assertThat(policy.maxDecodedPixels()).isEqualTo(16_000_000L);
        assertThat(policy.maxDimension()).isEqualTo(4_096);
        assertThat(policy.displayMaxLongSide()).isEqualTo(2_048);
        assertThat(policy.thumbnailMaxLongSide()).isEqualTo(360);
        assertThat(policy.acceptedInputContentTypes())
                .containsExactlyInAnyOrder("image/jpeg", "image/png");
        assertThat(policy.outputMimeType()).isEqualTo("image/jpeg");
        assertThat(policy.outputJpegQuality()).isEqualTo(85);
    }

    @Test
    void shouldDefensivelyCopyAcceptedInputContentTypes() {
        Set<String> accepted = new java.util.HashSet<>();
        accepted.add("image/jpeg");

        ImageProcessingPolicy policy = new ImageProcessingPolicy(
                1L,
                1L,
                1,
                1,
                1,
                accepted,
                "image/jpeg",
                85
        );

        accepted.add("image/png");

        assertThat(policy.acceptedInputContentTypes())
                .containsExactly("image/jpeg");
        assertThatThrownBy(() -> policy.acceptedInputContentTypes()
                .add("image/png"))
                .isInstanceOf(UnsupportedOperationException.class);
    }

    @Test
    void shouldRejectInvalidLimits() {
        assertThatThrownBy(assertInvalidPolicy(0L, 1L, 1, 1, 1))
                .hasMessage("maxUploadBytes must be positive");
        assertThatThrownBy(assertInvalidPolicy(1L, 0L, 1, 1, 1))
                .hasMessage("maxDecodedPixels must be positive");
        assertThatThrownBy(assertInvalidPolicy(1L, 1L, 0, 1, 1))
                .hasMessage("maxDimension must be positive");
        assertThatThrownBy(assertInvalidPolicy(1L, 1L, 1, 0, 1))
                .hasMessage("displayMaxLongSide must be positive");
        assertThatThrownBy(assertInvalidPolicy(1L, 1L, 1, 1, 0))
                .hasMessage("thumbnailMaxLongSide must be positive");
        assertThatThrownBy(assertInvalidPolicy(1L, 1L, 1, 2, 1))
                .hasMessage("displayMaxLongSide must not exceed maxDimension");
        assertThatThrownBy(assertInvalidPolicy(1L, 1L, 2, 1, 2))
                .hasMessage("thumbnailMaxLongSide must not exceed displayMaxLongSide");
    }

    @Test
    void shouldRejectInvalidContentTypesAndQuality() {
        assertThatThrownBy(() -> new ImageProcessingPolicy(
                1L,
                1L,
                1,
                1,
                1,
                null,
                "image/jpeg",
                85
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("acceptedInputContentTypes must not be null");

        assertThatThrownBy(() -> new ImageProcessingPolicy(
                1L,
                1L,
                1,
                1,
                1,
                Set.of(),
                "image/jpeg",
                85
        )).isInstanceOf(IllegalArgumentException.class)
                .hasMessage("acceptedInputContentTypes must not be empty");

        assertThatThrownBy(() -> new ImageProcessingPolicy(
                1L,
                1L,
                1,
                1,
                1,
                Set.of(" "),
                "image/jpeg",
                85
        )).isInstanceOf(IllegalArgumentException.class)
                .hasMessage("acceptedInputContentTypes must not contain blank values");

        assertThatThrownBy(() -> new ImageProcessingPolicy(
                1L,
                1L,
                1,
                1,
                1,
                Set.of("image/jpeg"),
                null,
                85
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("outputMimeType must not be null");

        assertThatThrownBy(() -> new ImageProcessingPolicy(
                1L,
                1L,
                1,
                1,
                1,
                Set.of("image/jpeg"),
                " ",
                85
        )).isInstanceOf(IllegalArgumentException.class)
                .hasMessage("outputMimeType must not be blank");

        assertThatThrownBy(() -> new ImageProcessingPolicy(
                1L,
                1L,
                1,
                1,
                1,
                Set.of("image/jpeg"),
                "image/jpeg",
                0
        )).isInstanceOf(IllegalArgumentException.class)
                .hasMessage("outputJpegQuality must be between 1 and 100");
    }

    @Test
    void shouldHaveSafeToString() {
        assertThat(ImageProcessingPolicy.mvpDefaults().toString())
                .contains("ImageProcessingPolicy")
                .contains("maxUploadBytes=5242880")
                .contains("outputMimeType=image/jpeg")
                .doesNotContain("image/png");
    }

    private static org.assertj.core.api.ThrowableAssert.ThrowingCallable
    assertInvalidPolicy(
            long maxUploadBytes,
            long maxDecodedPixels,
            int maxDimension,
            int displayMaxLongSide,
            int thumbnailMaxLongSide
    ) {
        return () -> new ImageProcessingPolicy(
                maxUploadBytes,
                maxDecodedPixels,
                maxDimension,
                displayMaxLongSide,
                thumbnailMaxLongSide,
                Set.of("image/jpeg"),
                "image/jpeg",
                85
        );
    }
}
