// SecurityConfig.java - this file is part of skills-testing-system
// Copyright (C) 2026  Kirill Rudkovskii
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

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
