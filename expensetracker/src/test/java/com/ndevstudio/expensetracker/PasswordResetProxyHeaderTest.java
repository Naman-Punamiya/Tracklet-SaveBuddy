package com.ndevstudio.expensetracker;

import com.ndevstudio.expensetracker.entity.User;
import com.ndevstudio.expensetracker.repository.PasswordResetTokenRepository;
import com.ndevstudio.expensetracker.repository.UserRepository;
import com.ndevstudio.expensetracker.service.PasswordResetEmailService;
import com.ndevstudio.expensetracker.service.PasswordResetService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;

import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@TestPropertySource(properties = {
        "app.security.trust-forward-headers=false",
        "app.reset-password.rate-limit.requests-per-window=3",
        "app.reset-password.rate-limit.window-minutes=15"
})
public class PasswordResetProxyHeaderTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private PasswordResetTokenRepository tokenRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private PasswordResetService passwordResetService;

    @MockBean
    private PasswordResetEmailService emailService;

    @BeforeEach
    void setUp() {
        passwordResetService.clearRateLimitState();
        tokenRepository.deleteAll();
        userRepository.deleteAll();
        reset(emailService);
        when(emailService.isConfiguredForDelivery()).thenReturn(true);
        when(emailService.sendResetEmail(anyString(), anyString())).thenReturn(true);

        User u = new User();
        u.setName("Proxy User");
        u.setEmail("proxy@example.com");
        u.setPassword(passwordEncoder.encode("OldPass123"));
        userRepository.save(u);
    }

    @Test
    void spoofedForwardedHeaders_areIgnoredWhenNotTrusted_soIpRateLimitCannotBeBypassed() throws Exception {
        // With trust-forward-headers=false, controller must ignore X-Forwarded-For/X-Real-IP and use remote address.
        // MockMvc uses a consistent remote address, so changing forwarded headers must not create new IP buckets.
        for (int i = 0; i < 3; i++) {
            mockMvc.perform(post("/api/users/forgot-password")
                            .contentType(MediaType.APPLICATION_JSON)
                            .header("X-Forwarded-For", "203.0.113." + i)
                            .header("X-Real-IP", "198.51.100." + i)
                            .content("{\"email\":\"proxy@example.com\"}"))
                    .andExpect(status().isOk());
        }

        mockMvc.perform(post("/api/users/forgot-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .header("X-Forwarded-For", "203.0.113.250")
                        .header("X-Real-IP", "198.51.100.250")
                        .content("{\"email\":\"proxy@example.com\"}"))
                .andExpect(status().isOk());

        // Only first 3 should pass IP rate limit bucket (email bucket same too); 4th blocked generically.
        verify(emailService, times(3)).sendResetEmail(eq("proxy@example.com"), anyString());
    }
}