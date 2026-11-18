package com.ndevstudio.expensetracker.controller;

import com.ndevstudio.expensetracker.dto.ForgotPasswordRequest;
import com.ndevstudio.expensetracker.dto.ResetPasswordRequest;
import com.ndevstudio.expensetracker.entity.User;
import com.ndevstudio.expensetracker.repository.UserRepository;
import com.ndevstudio.expensetracker.service.PasswordResetService;
import com.ndevstudio.expensetracker.service.UserService;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.Optional;

@RestController
@RequestMapping("/api/users")
public class UserRestController {

    @Autowired
    private UserRepository userRepository;
    @Autowired
    private PasswordEncoder passwordEncoder;
    @Autowired
    private UserService userService;
    @Autowired
    private PasswordResetService passwordResetService;

    @Value("${app.security.trust-forward-headers:false}")
    private boolean trustForwardHeaders;

    @PostMapping("/register")
    public ResponseEntity<?> registerUser(@RequestBody User user) {
        if (userRepository.existsByEmail(user.getEmail())) {
            return ResponseEntity
                    .status(HttpStatus.BAD_REQUEST)
                    .body("Email already exists");
        }
        user.setPassword(
                passwordEncoder.encode(user.getPassword())
        );
        User savedUser = userRepository.save(user);
        return ResponseEntity
                .status(HttpStatus.CREATED)
                .body(savedUser);
    }

    @PostMapping("/login")
    public ResponseEntity<?> loginUser(@RequestBody User loginRequest) {

        Optional<User> optionalUser =
                userRepository.findByEmail(loginRequest.getEmail());

        if (optionalUser.isEmpty()) {
            return ResponseEntity
                    .status(HttpStatus.NOT_FOUND)
                    .body("User not found");
        }

        User user = optionalUser.get();

        boolean isPasswordCorrect =
                passwordEncoder.matches(
                        loginRequest.getPassword(),
                        user.getPassword()
                );

        if (!isPasswordCorrect) {
            return ResponseEntity
                    .status(HttpStatus.UNAUTHORIZED)
                    .body("Invalid password");
        }

        return ResponseEntity.ok(user);
    }

    @GetMapping("/{id}")
    public ResponseEntity<?> getUserById(@PathVariable Long id, Authentication authentication) {
        if (authentication == null || !authentication.isAuthenticated()) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }
        User authUser = userRepository.findByEmail(authentication.getName()).orElse(null);
        if (authUser == null || authUser.getId() != id) {
            return ResponseEntity
                    .status(HttpStatus.NOT_FOUND)
                    .body("User not found");
        }
        return ResponseEntity.ok(authUser);
    }

    /**
     * Initiates password reset. Always returns a generic response to avoid account enumeration.
     */
    @PostMapping("/forgot-password")
    public ResponseEntity<Map<String, String>> forgotPassword(@RequestBody(required = false) ForgotPasswordRequest request,
                                                              HttpServletRequest httpRequest) {
        String clientIp = extractClientIp(httpRequest);
        try {
            passwordResetService.requestPasswordReset(request, clientIp);
        } catch (RuntimeException ex) {
            // Keep generic response and avoid exposing delivery/account details.
        }
        return ResponseEntity.ok(Map.of("message", passwordResetService.getGenericForgotPasswordMessage()));
    }

    /**
     * Resets password using a one-time reset token.
     */
    @PostMapping("/reset-password")
    public ResponseEntity<Map<String, String>> resetPassword(@RequestBody(required = false) ResetPasswordRequest request) {
        passwordResetService.resetPassword(request);
        return ResponseEntity.ok(Map.of("message", "Password has been reset successfully. You can now log in with your new password."));
    }

    /**
     * Permanently deletes the authenticated user's account and all associated cloud data.
     * Identifies account solely via the verified Spring Security principal (HTTP Basic Auth).
     * Rejects any client-specified identity and returns HTTP 204 No Content upon completion.
     */
    @DeleteMapping({"/delete-account", "/delete"})
    public ResponseEntity<Void> deleteAccount(Authentication authentication) {
        if (authentication == null || !authentication.isAuthenticated() || "anonymousUser".equals(authentication.getName())) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }

        userService.deleteUserAccount(authentication.getName());
        return ResponseEntity.noContent().build();
    }

    private String extractClientIp(HttpServletRequest request) {
        if (request == null) return "unknown";
        if (trustForwardHeaders) {
            String forwarded = request.getHeader("X-Forwarded-For");
            if (forwarded != null && !forwarded.isBlank()) {
                int comma = forwarded.indexOf(',');
                return (comma > 0 ? forwarded.substring(0, comma) : forwarded).trim();
            }
            String realIp = request.getHeader("X-Real-IP");
            if (realIp != null && !realIp.isBlank()) {
                return realIp.trim();
            }
        }
        return request.getRemoteAddr() != null ? request.getRemoteAddr() : "unknown";
    }
}
