package memory_map.backend.media.image.jvm;

import memory_map.backend.media.image.ImageProcessingPolicy;
import memory_map.backend.media.image.ImageProcessor;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;

import static org.assertj.core.api.Assertions.assertThat;

class JvmImageProcessingConfigurationTest {

    @Test
    void shouldRegisterImageProcessingBeans() {
        new ApplicationContextRunner()
                .withUserConfiguration(JvmImageProcessingConfiguration.class)
                .run(context -> {
                    assertThat(context)
                            .hasSingleBean(ImageProcessingPolicy.class);
                    assertThat(context)
                            .hasSingleBean(ImageProcessor.class);
                    assertThat(context.getBean(ImageProcessor.class))
                            .isInstanceOf(JvmImageProcessor.class);
                });
    }
}
