package com.ndevstudio.expensetracker;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.ndevstudio.expensetracker.entity.PasswordResetToken;
import com.ndevstudio.expensetracker.entity.User;
import com.ndevstudio.expensetracker.repository.PasswordResetTokenRepository;
import com.ndevstudio.expensetracker.repository.UserRepository;
import com.ndevstudio.expensetracker.service.PasswordResetEmailService;
import com.ndevstudio.expensetracker.service.PasswordResetService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.boot.test.mock.mockito.SpyBean;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.web.servlet.MockMvc;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.Base64;
import java.util.List;
import java.util.Map;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicInteger;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
public class PasswordResetIntegrationTest {

    private static final String GENERIC_MSG = "If an account exists with this email address, you will receive password reset instructions shortly.";

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @SpyBean
    private UserRepository userRepository;

    @Autowired
    private PasswordResetTokenRepository tokenRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private PasswordResetService passwordResetService;

    @MockBean
    private PasswordResetEmailService emailService;

    private User createUser(String name, String email, String rawPassword) {
        User u = new User();
        u.setName(name);
        u.setEmail(email);
        u.setPassword(passwordEncoder.encode(rawPassword));
        return userRepository.save(u);
    }

    private String basicAuthHeader(String email, String password) {
        return "Basic " + Base64.getEncoder().encodeToString((email + ":" + password).getBytes());
    }

    private String captureRawTokenForEmail(String email) {
        ArgumentCaptor<String> tokenCaptor = ArgumentCaptor.forClass(String.class);
        verify(emailService, atLeastOnce()).sendResetEmail(eq(email), tokenCaptor.capture());
        List<String> values = tokenCaptor.getAllValues();
        return values.get(values.size() - 1);
    }

    @BeforeEach
    void setUp() {
        reset(userRepository);
        passwordResetService.clearRateLimitState();
        tokenRepository.deleteAll();
        userRepository.deleteAll();
        reset(emailService);
        when(emailService.isConfiguredForDelivery()).thenReturn(true);
        when(emailService.sendResetEmail(anyString(), anyString())).thenReturn(true);
    }

    @Test
    void forgotPassword_existingEmail_returnsGenericResponse_andCreatesHashedToken() throws Exception {
        User user = createUser("Alice", "alice@example.com", "OldPass123");

        mockMvc.perform(post("/api/users/forgot-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("email", "alice@example.com"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message").value(GENERIC_MSG));

        ArgumentCaptor<String> tokenCaptor = ArgumentCaptor.forClass(String.class);
        verify(emailService, times(1)).sendResetEmail(eq("alice@example.com"), tokenCaptor.capture());
        String rawToken = tokenCaptor.getValue();
        assertNotNull(rawToken);
        assertFalse(rawToken.isBlank());

        List<PasswordResetToken> tokens = tokenRepository.findByUser(user);
        assertEquals(1, tokens.size());
        PasswordResetToken t = tokens.get(0);
        assertNotNull(t.getTokenHash());
        assertNotEquals(rawToken, t.getTokenHash());
        assertEquals(passwordResetService.hashToken(rawToken), t.getTokenHash());
        assertNull(t.getUsedAt());
        assertNotNull(t.getExpiresAt());
        assertTrue(t.getExpiresAt().isAfter(Instant.now()));
    }

    @Test
    void forgotPassword_nonexistentEmail_returnsSameGenericResponse_andDoesNotSend() throws Exception {
        mockMvc.perform(post("/api/users/forgot-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("email", "nobody@example.com"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message").value(GENERIC_MSG));

        verify(emailService, never()).sendResetEmail(anyString(), anyString());
        assertEquals(0, tokenRepository.count());
    }

    @Test
    void validToken_resetsPassword_andInvalidatesToken_andAuthBehaviorUpdated() throws Exception {
        User user = createUser("Bob", "bob@example.com", "OldPass123");
        String oldHash = user.getPassword();

        mockMvc.perform(post("/api/users/forgot-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("email", "bob@example.com"))))
                .andExpect(status().isOk());

        String rawToken = captureRawTokenForEmail("bob@example.com");

        mockMvc.perform(post("/api/users/reset-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("token", rawToken, "newPassword", "NewPass123"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message").exists());

        User updated = userRepository.findByEmail("bob@example.com").orElseThrow();
        assertNotEquals(oldHash, updated.getPassword());
        assertTrue(passwordEncoder.matches("NewPass123", updated.getPassword()));
        assertFalse(passwordEncoder.matches("OldPass123", updated.getPassword()));

        PasswordResetToken token = tokenRepository.findByUser(user).get(0);
        assertNotNull(token.getUsedAt());

        // Old password no longer authenticates, new password authenticates
        mockMvc.perform(post("/api/users/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"bob@example.com\",\"password\":\"OldPass123\"}"))
                .andExpect(status().isUnauthorized());

        mockMvc.perform(post("/api/users/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"bob@example.com\",\"password\":\"NewPass123\"}"))
                .andExpect(status().isOk());
    }

    @Test
    void invalidToken_isRejected() throws Exception {
        mockMvc.perform(post("/api/users/reset-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("token", "not-a-real-token", "newPassword", "NewPass123"))))
                .andExpect(status().isBadRequest());
    }

    @Test
    void expiredToken_isRejected_andMarkedUsed() throws Exception {
        User user = createUser("Cara", "cara@example.com", "OldPass123");
        mockMvc.perform(post("/api/users/forgot-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("email", "cara@example.com"))))
                .andExpect(status().isOk());

        String rawToken = captureRawTokenForEmail("cara@example.com");
        PasswordResetToken token = tokenRepository.findByUser(user).get(0);
        token.setExpiresAt(Instant.now().minus(1, ChronoUnit.MINUTES));
        tokenRepository.saveAndFlush(token);

        mockMvc.perform(post("/api/users/reset-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("token", rawToken, "newPassword", "NewPass123"))))
                .andExpect(status().isBadRequest());

        PasswordResetToken updated = tokenRepository.findById(token.getId()).orElseThrow();
        assertNotNull(updated.getUsedAt());
        User unchanged = userRepository.findByEmail("cara@example.com").orElseThrow();
        assertTrue(passwordEncoder.matches("OldPass123", unchanged.getPassword()));
    }

    @Test
    void reusedToken_isRejected() throws Exception {
        createUser("Dan", "dan@example.com", "OldPass123");
        mockMvc.perform(post("/api/users/forgot-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("email", "dan@example.com"))))
                .andExpect(status().isOk());
        String rawToken = captureRawTokenForEmail("dan@example.com");

        mockMvc.perform(post("/api/users/reset-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("token", rawToken, "newPassword", "NewPass123"))))
                .andExpect(status().isOk());

        mockMvc.perform(post("/api/users/reset-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("token", rawToken, "newPassword", "Another123"))))
                .andExpect(status().isBadRequest());

        User user = userRepository.findByEmail("dan@example.com").orElseThrow();
        assertTrue(passwordEncoder.matches("NewPass123", user.getPassword()));
    }

    @Test
    void previousToken_invalidated_whenNewRequestMade() throws Exception {
        User user = createUser("Eve", "eve@example.com", "OldPass123");

        mockMvc.perform(post("/api/users/forgot-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("email", "eve@example.com"))))
                .andExpect(status().isOk());
        ArgumentCaptor<String> captor1 = ArgumentCaptor.forClass(String.class);
        verify(emailService, times(1)).sendResetEmail(eq("eve@example.com"), captor1.capture());
        String token1 = captor1.getValue();

        mockMvc.perform(post("/api/users/forgot-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("email", "eve@example.com"))))
                .andExpect(status().isOk());
        ArgumentCaptor<String> captor2 = ArgumentCaptor.forClass(String.class);
        verify(emailService, times(2)).sendResetEmail(eq("eve@example.com"), captor2.capture());
        String token2 = captor2.getAllValues().get(1);
        assertNotEquals(token1, token2);

        List<PasswordResetToken> tokens = tokenRepository.findByUser(user);
        assertEquals(2, tokens.size());
        String hash1 = passwordResetService.hashToken(token1);
        String hash2 = passwordResetService.hashToken(token2);
        PasswordResetToken t1 = tokens.stream().filter(t -> t.getTokenHash().equals(hash1)).findFirst().orElseThrow();
        PasswordResetToken t2 = tokens.stream().filter(t -> t.getTokenHash().equals(hash2)).findFirst().orElseThrow();
        assertNotNull(t1.getUsedAt(), "previous token should be invalidated");
        assertNull(t2.getUsedAt(), "new token should remain usable");

        mockMvc.perform(post("/api/users/reset-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("token", token1, "newPassword", "NewPass123"))))
                .andExpect(status().isBadRequest());

        mockMvc.perform(post("/api/users/reset-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("token", token2, "newPassword", "NewPass123"))))
                .andExpect(status().isOk());
    }

    @Test
    void otherOutstandingTokens_invalidated_afterSuccessfulReset() throws Exception {
        User user = createUser("Finn", "finn@example.com", "OldPass123");

        mockMvc.perform(post("/api/users/forgot-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .header("X-Forwarded-For", "10.0.0.1")
                        .content(objectMapper.writeValueAsString(Map.of("email", "finn@example.com"))))
                .andExpect(status().isOk());
        ArgumentCaptor<String> captor = ArgumentCaptor.forClass(String.class);
        verify(emailService, times(1)).sendResetEmail(eq("finn@example.com"), captor.capture());
        String token1 = captor.getValue();

        // create a second outstanding token directly (simulate another issued token)
        PasswordResetToken extra = new PasswordResetToken();
        extra.setUser(user);
        extra.setCreatedAt(Instant.now());
        extra.setExpiresAt(Instant.now().plus(20, ChronoUnit.MINUTES));
        extra.setTokenHash(passwordResetService.hashToken("extra-raw-token-value-1234567890"));
        tokenRepository.saveAndFlush(extra);

        mockMvc.perform(post("/api/users/reset-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("token", token1, "newPassword", "NewPass123"))))
                .andExpect(status().isOk());

        List<PasswordResetToken> tokens = tokenRepository.findByUser(user);
        assertTrue(tokens.stream().allMatch(t -> t.getUsedAt() != null), "all outstanding tokens must be invalidated");
    }

    @Test
    void newPassword_storedUsingExistingPasswordEncoder() throws Exception {
        User user = createUser("Gina", "gina@example.com", "OldPass123");
        mockMvc.perform(post("/api/users/forgot-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("email", "gina@example.com"))))
                .andExpect(status().isOk());
        String rawToken = captureRawTokenForEmail("gina@example.com");

        mockMvc.perform(post("/api/users/reset-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("token", rawToken, "newPassword", "NewPass123"))))
                .andExpect(status().isOk());

        User updated = userRepository.findByEmail("gina@example.com").orElseThrow();
        assertTrue(updated.getPassword().startsWith("$2"), "password should be BCrypt-hashed by existing encoder");
        assertTrue(passwordEncoder.matches("NewPass123", updated.getPassword()));
    }

    @Test
    void invalidPasswords_areRejected() throws Exception {
        createUser("Hank", "hank@example.com", "OldPass123");
        mockMvc.perform(post("/api/users/forgot-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("email", "hank@example.com"))))
                .andExpect(status().isOk());
        String rawToken = captureRawTokenForEmail("hank@example.com");

        List<String> badPasswords = List.of("", "short1", "abcdefgh", "12345678", "        ");
        for (String bad : badPasswords) {
            mockMvc.perform(post("/api/users/reset-password")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(objectMapper.writeValueAsString(Map.of("token", rawToken, "newPassword", bad))))
                    .andExpect(status().isBadRequest());
        }

        User unchanged = userRepository.findByEmail("hank@example.com").orElseThrow();
        assertTrue(passwordEncoder.matches("OldPass123", unchanged.getPassword()));
    }

    @Test
    void rateLimiting_works_andReturnsGenericResponse() throws Exception {
        createUser("Ivy", "ivy@example.com", "OldPass123");

        for (int i = 0; i < 3; i++) {
            mockMvc.perform(post("/api/users/forgot-password")
                            .contentType(MediaType.APPLICATION_JSON)
                            .header("X-Forwarded-For", "203.0.113.10")
                            .content(objectMapper.writeValueAsString(Map.of("email", "ivy@example.com"))))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.message").value(GENERIC_MSG));
        }
        // 4th request should be throttled but still generic; no additional email
        mockMvc.perform(post("/api/users/forgot-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .header("X-Forwarded-For", "203.0.113.10")
                        .content(objectMapper.writeValueAsString(Map.of("email", "ivy@example.com"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message").value(GENERIC_MSG));

        verify(emailService, times(3)).sendResetEmail(eq("ivy@example.com"), anyString());
    }

    @Test
    void concurrentTokenConsumption_cannotResetPasswordMoreThanOnce() throws Exception {
        User user = createUser("Jill", "jill@example.com", "OldPass123");
        mockMvc.perform(post("/api/users/forgot-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("email", "jill@example.com"))))
                .andExpect(status().isOk());
        String rawToken = captureRawTokenForEmail("jill@example.com");

        int threads = 2;
        ExecutorService executor = Executors.newFixedThreadPool(threads);
        CountDownLatch ready = new CountDownLatch(threads);
        CountDownLatch start = new CountDownLatch(1);
        List<Future<Integer>> futures = new ArrayList<>();
        for (int i = 0; i < threads; i++) {
            futures.add(executor.submit(() -> {
                ready.countDown();
                start.await(5, TimeUnit.SECONDS);
                try {
                    return mockMvc.perform(post("/api/users/reset-password")
                                    .contentType(MediaType.APPLICATION_JSON)
                                    .content(objectMapper.writeValueAsString(Map.of("token", rawToken, "newPassword", "NewPass123"))))
                            .andReturn().getResponse().getStatus();
                } catch (Exception e) {
                    return 500;
                }
            }));
        }
        ready.await(5, TimeUnit.SECONDS);
        start.countDown();
        int success = 0;
        int bad = 0;
        for (Future<Integer> f : futures) {
            int s = f.get(10, TimeUnit.SECONDS);
            if (s == 200) success++;
            else if (s == 400) bad++;
        }
        executor.shutdownNow();

        assertEquals(1, success, "exactly one concurrent reset should succeed");
        assertEquals(1, bad, "other concurrent attempt should be rejected");
        User updated = userRepository.findByEmail("jill@example.com").orElseThrow();
        assertTrue(passwordEncoder.matches("NewPass123", updated.getPassword()));
    }

    @Test
    void transactionRollback_preservesState_whenResetOperationFailsAfterPartialWork() throws Exception {
        User user = createUser("Karl", "karl@example.com", "OldPass123");
        mockMvc.perform(post("/api/users/forgot-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("email", "karl@example.com"))))
                .andExpect(status().isOk());
        String rawToken = captureRawTokenForEmail("karl@example.com");
        String oldHash = userRepository.findByEmail("karl@example.com").orElseThrow().getPassword();

        doThrow(new RuntimeException("Simulated DB failure"))
                .when(userRepository).save(any(User.class));

        try {
            Exception ex = assertThrows(Exception.class, () -> mockMvc.perform(post("/api/users/reset-password")
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(objectMapper.writeValueAsString(Map.of("token", rawToken, "newPassword", "NewPass123")))));
            Throwable root = ex;
            while (root.getCause() != null) {
                root = root.getCause();
            }
            assertTrue(root instanceof RuntimeException);
            assertEquals("Simulated DB failure", root.getMessage());
        } finally {
            reset(userRepository);
        }

        User unchanged = userRepository.findByEmail("karl@example.com").orElseThrow();
        assertEquals(oldHash, unchanged.getPassword(), "password must remain unchanged on rollback");
        assertTrue(passwordEncoder.matches("OldPass123", unchanged.getPassword()));

        PasswordResetToken token = tokenRepository.findByUser(user).get(0);
        assertNull(token.getUsedAt(), "token must not be consumed if transaction rolled back");

        // token should still be usable after rollback failure
        mockMvc.perform(post("/api/users/reset-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("token", rawToken, "newPassword", "NewPass123"))))
                .andExpect(status().isOk());
    }

    @Test
    void forgotPassword_whenEmailDeliveryFails_returnsGenericResponse_andRollsBackTokenState() throws Exception {
        User user = createUser("Liam", "liam@example.com", "OldPass123");
        when(emailService.sendResetEmail(eq("liam@example.com"), anyString())).thenReturn(false);

        mockMvc.perform(post("/api/users/forgot-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("email", "liam@example.com"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message").value(GENERIC_MSG));

        // Delivery failed after token creation attempt; transaction must roll back so no token remains.
        assertEquals(0, tokenRepository.findByUser(user).size(), "failed delivery must not leave a usable/lingering token state");
        verify(emailService, times(1)).sendResetEmail(eq("liam@example.com"), anyString());
    }

    @Test
    void forgotPassword_whenEmailNotConfigured_returnsGenericResponse_withoutRotatingTokens() throws Exception {
        User user = createUser("Mia", "mia@example.com", "OldPass123");

        // Seed an existing valid token state
        PasswordResetToken existing = new PasswordResetToken();
        existing.setUser(user);
        existing.setCreatedAt(Instant.now());
        existing.setExpiresAt(Instant.now().plus(20, ChronoUnit.MINUTES));
        existing.setTokenHash(passwordResetService.hashToken("seed-token-raw-value-1234567890"));
        tokenRepository.saveAndFlush(existing);

        when(emailService.isConfiguredForDelivery()).thenReturn(false);

        mockMvc.perform(post("/api/users/forgot-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("email", "mia@example.com"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message").value(GENERIC_MSG));

        List<PasswordResetToken> tokens = tokenRepository.findByUser(user);
        assertEquals(1, tokens.size(), "missing config must not rotate/invalidate existing tokens");
        assertNull(tokens.get(0).getUsedAt());
        verify(emailService, never()).sendResetEmail(anyString(), anyString());
    }

    @Test
    void forgotPassword_malformedOversizedAndNullInputs_returnGenericAndDoNotLeak() throws Exception {
        createUser("Nina", "nina@example.com", "OldPass123");

        mockMvc.perform(post("/api/users/forgot-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":null}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message").value(GENERIC_MSG));

        mockMvc.perform(post("/api/users/forgot-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":12345}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message").value(GENERIC_MSG)); // coercion/handling must remain generic, no account leak or send

        String longEmail = "a".repeat(300) + "@example.com";
        mockMvc.perform(post("/api/users/forgot-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("email", longEmail))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message").value(GENERIC_MSG));

        mockMvc.perform(post("/api/users/forgot-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message").value(GENERIC_MSG));

        verify(emailService, never()).sendResetEmail(anyString(), anyString());
    }

    @Test
    void resetPassword_rejectsNullMalformedAndOversizedInputs() throws Exception {
        mockMvc.perform(post("/api/users/reset-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isBadRequest());

        mockMvc.perform(post("/api/users/reset-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"token\":null,\"newPassword\":\"NewPass123\"}"))
                .andExpect(status().isBadRequest());

        String hugeToken = "t".repeat(600);
        mockMvc.perform(post("/api/users/reset-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("token", hugeToken, "newPassword", "NewPass123"))))
                .andExpect(status().isBadRequest());

        String hugePassword = "A1" + "a".repeat(200);
        mockMvc.perform(post("/api/users/reset-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("token", "some-token", "newPassword", hugePassword))))
                .andExpect(status().isBadRequest());
    }
}
