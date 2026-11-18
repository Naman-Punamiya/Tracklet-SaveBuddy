package com.ndevstudio.expensetracker.service;

import com.ndevstudio.expensetracker.dto.ForgotPasswordRequest;
import com.ndevstudio.expensetracker.dto.ResetPasswordRequest;
import com.ndevstudio.expensetracker.entity.PasswordResetToken;
import com.ndevstudio.expensetracker.entity.User;
import com.ndevstudio.expensetracker.repository.PasswordResetTokenRepository;
import com.ndevstudio.expensetracker.repository.UserRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;
import org.springframework.web.server.ResponseStatusException;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.ArrayDeque;
import java.util.Base64;
import java.util.Deque;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
import java.util.regex.Pattern;

@Service
public class PasswordResetService {

    private static final Logger log = LoggerFactory.getLogger(PasswordResetService.class);
    private static final Pattern EMAIL_PATTERN = Pattern.compile("^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$");
    private static final String GENERIC_FORGOT_MESSAGE = "If an account exists with this email address, you will receive password reset instructions shortly.";
    private static final int MAX_TRACKED_RATE_LIMIT_KEYS = 10000;
    private static final int MAX_EMAIL_LENGTH = 254;
    private static final int MAX_IP_LENGTH = 64;
    private static final int MAX_TOKEN_LENGTH = 512;

    static class PasswordResetDeliveryException extends RuntimeException {
        PasswordResetDeliveryException(String message) {
            super(message);
        }
    }

    private final UserRepository userRepository;
    private final PasswordResetTokenRepository tokenRepository;
    private final PasswordEncoder passwordEncoder;
    private final PasswordResetEmailService emailService;
    private final SecureRandom secureRandom = new SecureRandom();

    private final Map<String, Deque<Instant>> emailRequestWindows = new ConcurrentHashMap<>();
    private final Map<String, Deque<Instant>> ipRequestWindows = new ConcurrentHashMap<>();

    @Value("${app.reset-password.token-expiry-minutes:20}")
    private int expiryMinutes;

    @Value("${app.reset-password.rate-limit.requests-per-window:3}")
    private int maxRequestsPerWindow;

    @Value("${app.reset-password.rate-limit.window-minutes:15}")
    private int rateLimitWindowMinutes;

    public PasswordResetService(UserRepository userRepository,
                                PasswordResetTokenRepository tokenRepository,
                                PasswordEncoder passwordEncoder,
                                PasswordResetEmailService emailService) {
        this.userRepository = userRepository;
        this.tokenRepository = tokenRepository;
        this.passwordEncoder = passwordEncoder;
        this.emailService = emailService;
    }

    public String getGenericForgotPasswordMessage() {
        return GENERIC_FORGOT_MESSAGE;
    }

    // Visible for tests to ensure isolation in shared Spring contexts.
    public void clearRateLimitState() {
        emailRequestWindows.clear();
        ipRequestWindows.clear();
    }

    @Transactional
    public void requestPasswordReset(ForgotPasswordRequest request, String clientIp) {
        String rawEmail = request == null ? null : request.getEmail();
        String normalizedEmail = normalizeEmail(rawEmail);

        // Always enforce rate limiting checks and return generic response behavior at controller level.
        if (!isValidEmail(normalizedEmail)) {
            return;
        }

        if (isRateLimited("email:" + normalizedEmail, emailRequestWindows)
                || isRateLimited("ip:" + normalizeIp(clientIp), ipRequestWindows)) {
            // Generic handling: do not reveal throttling/account existence and do not send.
            return;
        }

        Optional<User> userOpt = userRepository.findByEmail(normalizedEmail);
        if (userOpt.isEmpty()) {
            return;
        }

        // Do not rotate/invalidate tokens if delivery is not configured; avoid misleading internal state.
        if (!emailService.isConfiguredForDelivery()) {
            log.warn("Password reset request accepted but email delivery is not fully configured; token state unchanged");
            return;
        }

        User user = userOpt.get();
        Instant now = Instant.now();
        tokenRepository.invalidateAllUnusedForUser(user, now);

        String rawToken = generateRawToken();
        String tokenHash = hashToken(rawToken);

        PasswordResetToken token = new PasswordResetToken();
        token.setUser(user);
        token.setTokenHash(tokenHash);
        token.setCreatedAt(now);
        token.setExpiresAt(now.plus(Math.max(1, expiryMinutes), ChronoUnit.MINUTES));
        tokenRepository.save(token);
        tokenRepository.flush();

        try {
            boolean sent = emailService.sendResetEmail(user.getEmail(), rawToken);
            if (!sent) {
                // Roll back token creation/invalidation so user is not left without any usable reset token state.
                throw new PasswordResetDeliveryException("Password reset email was not delivered");
            }
        } catch (PasswordResetDeliveryException ex) {
            throw ex;
        } catch (Exception ex) {
            // Never expose account existence or token details; rollback state.
            throw new PasswordResetDeliveryException("Unexpected error while sending password reset email");
        }
    }

    @Transactional(noRollbackFor = ResponseStatusException.class)
    public void resetPassword(ResetPasswordRequest request) {
        String rawToken = request == null ? null : trimToNull(request.getToken());
        String newPassword = request == null ? null : request.getNewPassword();

        if (!StringUtils.hasText(rawToken)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Reset token is required");
        }
        if (rawToken.length() > MAX_TOKEN_LENGTH) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Invalid or expired reset token");
        }
        validateNewPassword(newPassword);

        String tokenHash = hashToken(rawToken);
        Instant now = Instant.now();

        PasswordResetToken token = tokenRepository.findByTokenHashForUpdate(tokenHash)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.BAD_REQUEST, "Invalid or expired reset token"));

        if (token.getUsedAt() != null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Reset token has already been used");
        }
        if (token.getExpiresAt() == null || !token.getExpiresAt().isAfter(now)) {
            token.setUsedAt(now);
            tokenRepository.save(token);
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Reset token has expired");
        }

        User user = token.getUser();
        if (user == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Invalid or expired reset token");
        }

        user.setPassword(passwordEncoder.encode(newPassword));
        userRepository.save(user);

        token.setUsedAt(now);
        tokenRepository.save(token);

        // Invalidate any other outstanding reset tokens for this user.
        tokenRepository.invalidateAllUnusedForUser(user, now);
    }

    private void validateNewPassword(String password) {
        if (!StringUtils.hasText(password)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "New password is required");
        }
        String trimmed = password.trim();
        if (trimmed.length() < 8) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Password must be at least 8 characters long");
        }
        if (trimmed.length() > 128) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Password is too long");
        }
        boolean hasLetter = trimmed.chars().anyMatch(Character::isLetter);
        boolean hasDigit = trimmed.chars().anyMatch(Character::isDigit);
        if (!hasLetter || !hasDigit) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Password must include at least one letter and one number");
        }
    }

    private boolean isRateLimited(String key, Map<String, Deque<Instant>> windows) {
        if (!StringUtils.hasText(key)) {
            return false;
        }
        Instant now = Instant.now();
        Instant cutoff = now.minus(Math.max(1, rateLimitWindowMinutes), ChronoUnit.MINUTES);

        // Opportunistic cleanup to prevent unbounded growth from arbitrary keys.
        cleanupRateLimitMap(windows, cutoff);

        Deque<Instant> deque = windows.computeIfAbsent(key, k -> new ArrayDeque<>());
        synchronized (deque) {
            pruneDeque(deque, cutoff);
            if (deque.size() >= Math.max(1, maxRequestsPerWindow)) {
                if (deque.isEmpty()) {
                    windows.remove(key, deque);
                }
                return true;
            }
            deque.addLast(now);
        }
        return false;
    }

    private void cleanupRateLimitMap(Map<String, Deque<Instant>> windows, Instant cutoff) {
        if (windows.size() <= MAX_TRACKED_RATE_LIMIT_KEYS) {
            // Light cleanup pass: remove empty/stale entries encountered is enough in normal cases.
            if (windows.size() > (MAX_TRACKED_RATE_LIMIT_KEYS / 2)) {
                windows.entrySet().removeIf(entry -> {
                    Deque<Instant> dq = entry.getValue();
                    synchronized (dq) {
                        pruneDeque(dq, cutoff);
                        return dq.isEmpty();
                    }
                });
            }
            return;
        }

        windows.entrySet().removeIf(entry -> {
            Deque<Instant> dq = entry.getValue();
            synchronized (dq) {
                pruneDeque(dq, cutoff);
                return dq.isEmpty();
            }
        });

        // If still above cap after stale cleanup, drop arbitrary oldest-evictable entries as safety bound.
        if (windows.size() > MAX_TRACKED_RATE_LIMIT_KEYS) {
            int toRemove = windows.size() - MAX_TRACKED_RATE_LIMIT_KEYS;
            for (String k : windows.keySet()) {
                if (toRemove <= 0) break;
                Deque<Instant> dq = windows.get(k);
                if (dq == null) continue;
                synchronized (dq) {
                    if (dq.isEmpty()) {
                        windows.remove(k, dq);
                        toRemove--;
                    }
                }
            }
        }
    }

    private void pruneDeque(Deque<Instant> deque, Instant cutoff) {
        while (!deque.isEmpty() && !deque.peekFirst().isAfter(cutoff)) {
            deque.pollFirst();
        }
    }

    private String generateRawToken() {
        byte[] bytes = new byte[32]; // 256 bits
        secureRandom.nextBytes(bytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }

    public String hashToken(String rawToken) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hashed = digest.digest(rawToken.getBytes(StandardCharsets.UTF_8));
            return Base64.getEncoder().encodeToString(hashed);
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 not available", e);
        }
    }

    private boolean isValidEmail(String email) {
        return StringUtils.hasText(email) && EMAIL_PATTERN.matcher(email).matches();
    }

    private String normalizeEmail(String email) {
        if (email == null) return null;
        String trimmed = email.trim().toLowerCase(Locale.ROOT);
        if (trimmed.isEmpty() || trimmed.length() > MAX_EMAIL_LENGTH) {
            return null;
        }
        return trimmed;
    }

    private String normalizeIp(String ip) {
        if (!StringUtils.hasText(ip)) {
            return "unknown";
        }
        String trimmed = ip.trim();
        if (trimmed.length() > MAX_IP_LENGTH) {
            return trimmed.substring(0, MAX_IP_LENGTH);
        }
        return trimmed;
    }

    private String trimToNull(String value) {
        if (value == null) return null;
        String trimmed = value.trim();
        return trimmed.isEmpty() ? null : trimmed;
    }
}
