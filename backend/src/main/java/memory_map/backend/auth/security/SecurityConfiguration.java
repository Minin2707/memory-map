package memory_map.backend.auth.security;

import memory_map.backend.ratelimit.RequestRateLimitFilter;
import memory_map.backend.user.repository.UserRepository;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.Customizer;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.access.intercept.AuthorizationFilter;

@Configuration
public class SecurityConfiguration {

    @Bean
    public SecurityFilterChain securityFilterChain(
            HttpSecurity http,
            ObjectProvider<RequestRateLimitFilter> rateLimitFilter
    )
            throws Exception {

        http
                .csrf(AbstractHttpConfigurer::disable)
                .sessionManagement(sessionManagement -> sessionManagement
                        .sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .headers(headers -> headers.httpStrictTransportSecurity(
                        hsts -> hsts
                                .maxAgeInSeconds(31_536_000)
                                .includeSubDomains(false)
                ))
                .authorizeHttpRequests(authorize -> authorize
                        .requestMatchers("/api/v1/auth/**").permitAll()
                        .anyRequest().authenticated())
                .oauth2ResourceServer(oauth2ResourceServer ->
                        oauth2ResourceServer.jwt(Customizer.withDefaults()))
                .formLogin(AbstractHttpConfigurer::disable)
                .httpBasic(AbstractHttpConfigurer::disable)
                .logout(AbstractHttpConfigurer::disable);

        rateLimitFilter.ifAvailable(filter ->
                http.addFilterAfter(filter, AuthorizationFilter.class)
        );

        return http.build();
    }

    @Bean
    public CurrentAuthenticatedUserProvider currentAuthenticatedUserProvider(
            ObjectProvider<UserRepository> userRepositoryProvider
    ) {
        UserRepository userRepository = userRepositoryProvider.getIfAvailable();

        if (userRepository == null) {
            return new SpringSecurityCurrentAuthenticatedUserProvider();
        }

        return new SpringSecurityCurrentAuthenticatedUserProvider(
                userRepository
        );
    }
}
