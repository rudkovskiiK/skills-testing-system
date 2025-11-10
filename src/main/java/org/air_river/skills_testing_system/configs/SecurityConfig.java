package org.air_river.skills_testing_system.configs;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;

@Configuration
@EnableWebSecurity
public class SecurityConfig {
    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity httpSecurity) throws Exception {
        httpSecurity.authorizeHttpRequests(requests ->
            requests.requestMatchers("/js/*", "/css/*")
            .permitAll()
            .anyRequest().authenticated()
        ).formLogin(form ->
            form.loginPage("/login")
            .defaultSuccessUrl("/")
            .permitAll()
        ).logout(logout ->
            logout.logoutUrl("/logout")
            .logoutSuccessUrl("/")
        ).sessionManagement(sessions ->
            sessions.sessionConcurrency(concurrency ->
                concurrency.maximumSessions(1)
            )
        );
        return httpSecurity.build();
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder(12);
    }
}
