package memory_map.backend.media.image.jvm;

import memory_map.backend.media.image.ImageProcessingPolicy;
import memory_map.backend.media.image.ImageProcessor;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class JvmImageProcessingConfiguration {

    @Bean
    public ImageProcessingPolicy imageProcessingPolicy() {
        return ImageProcessingPolicy.mvpDefaults();
    }

    @Bean
    public ImageProcessor imageProcessor(ImageProcessingPolicy policy) {
        return new JvmImageProcessor(policy);
    }
}
