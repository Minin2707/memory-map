package memory_map.backend.auth.google;

import com.google.api.client.googleapis.auth.oauth2.GoogleIdTokenVerifier;
import com.google.api.client.googleapis.javanet.GoogleNetHttpTransport;
import com.google.api.client.http.HttpTransport;
import com.google.api.client.json.JsonFactory;
import com.google.api.client.json.gson.GsonFactory;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.io.IOException;
import java.security.GeneralSecurityException;
import java.util.List;

@Configuration
@EnableConfigurationProperties(GoogleAuthProperties.class)
public class GoogleIdentityVerifierConfiguration {

    @Bean
    public HttpTransport googleHttpTransport()
            throws GeneralSecurityException, IOException {

        return GoogleNetHttpTransport.newTrustedTransport();
    }

    @Bean
    public JsonFactory googleJsonFactory() {

        return GsonFactory.getDefaultInstance();
    }

    @Bean
    public GoogleIdTokenVerifier googleIdTokenVerifier(
            HttpTransport googleHttpTransport,
            JsonFactory googleJsonFactory,
            GoogleAuthProperties properties
    ) {
        return new GoogleIdTokenVerifier.Builder(
                googleHttpTransport,
                googleJsonFactory
        )
                .setAudience(List.of(properties.clientId()))
                .build();
    }

    @Bean
    public GoogleSdkTokenVerifier googleSdkTokenVerifier(
            GoogleIdTokenVerifier googleIdTokenVerifier
    ) {
        return new GoogleApiIdTokenVerifier(googleIdTokenVerifier);
    }

    @Bean
    public GoogleIdentityVerifier googleIdentityVerifier(
            GoogleSdkTokenVerifier googleSdkTokenVerifier
    ) {
        return new GoogleApiGoogleIdentityVerifier(googleSdkTokenVerifier);
    }
}
