package com.ndevstudio.expensetracker.service;

import jakarta.mail.internet.MimeMessage;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.MimeMessageHelper;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;
import org.springframework.web.util.UriComponentsBuilder;

import java.nio.charset.StandardCharsets;

@Service
public class PasswordResetEmailService {

    private static final Logger log = LoggerFactory.getLogger(PasswordResetEmailService.class);

    private final JavaMailSender mailSender;

    @Value("${app.mail.from:}")
    private String mailFrom;

    @Value("${app.mail.from-name:Tracklet SaveBuddy}")
    private String mailFromName;

    // Preferred: configurable base URL, e.g. https://auth.namanpunamiya.me
    @Value("${app.reset-password.base-url:}")
    private String resetPasswordBaseUrl;

    // Backward-compatible full URL, e.g. https://auth.namanpunamiya.me/reset-password
    @Value("${app.reset-password.url:}")
    private String resetPasswordUrl;

    @Value("${app.reset-password.token-expiry-minutes:20}")
    private int expiryMinutes;

    public PasswordResetEmailService(JavaMailSender mailSender) {
        this.mailSender = mailSender;
    }

    public boolean sendResetEmail(String toEmail, String rawToken) {
        if (!StringUtils.hasText(toEmail) || !StringUtils.hasText(rawToken)) {
            return false;
        }
        String resolvedResetUrl = resolveResetUrl();
        if (!isConfiguredForDelivery(resolvedResetUrl)) {
            log.warn("Password reset email not sent: email delivery is not fully configured");
            return false;
        }

        try {
            String link = UriComponentsBuilder.fromUriString(resolvedResetUrl)
                    .queryParam("token", rawToken)
                    .build()
                    .encode(StandardCharsets.UTF_8)
                    .toUriString();

            // Enforce HTTPS for production-style reset links when configured.
            if (!link.regionMatches(true, 0, "https://", 0, 8)) {
                log.warn("Password reset email not sent: reset URL must use HTTPS");
                return false;
            }

            String subject = "Reset your Tracklet SaveBuddy password";
            String html = buildHtml(link, expiryMinutes);

            MimeMessage message = mailSender.createMimeMessage();
            MimeMessageHelper helper = new MimeMessageHelper(message, "UTF-8");
            if (StringUtils.hasText(mailFromName)) {
                helper.setFrom(mailFrom, mailFromName);
            } else {
                helper.setFrom(mailFrom);
            }
            helper.setTo(toEmail);
            helper.setSubject(subject);
            helper.setText(html, true);

            mailSender.send(message);
            return true;
        } catch (Exception ex) {
            // Never log raw token or reset link.
            log.error("Failed to send password reset email for a reset request", ex);
            return false;
        }
    }

    public boolean isConfiguredForDelivery() {
        return isConfiguredForDelivery(resolveResetUrl());
    }

    private boolean isConfiguredForDelivery(String resolvedResetUrl) {
        return StringUtils.hasText(mailFrom) && StringUtils.hasText(resolvedResetUrl);
    }

    private String resolveResetUrl() {
        if (StringUtils.hasText(resetPasswordBaseUrl)) {
            String base = resetPasswordBaseUrl.trim();
            while (base.endsWith("/")) {
                base = base.substring(0, base.length() - 1);
            }
            return base + "/reset-password";
        }
        return StringUtils.hasText(resetPasswordUrl) ? resetPasswordUrl.trim() : "";
    }

    private String buildHtml(String link, int expiryMinutes) {
        String safeLink = escapeHtml(link);
        return "<!DOCTYPE html>" +
                "<html lang=\"en\"><head><meta charset=\"UTF-8\">" +
                "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">" +
                "<title>Reset your password</title></head>" +
                "<body style=\"margin:0;padding:0;background:#f4f6f8;font-family:Arial,Helvetica,sans-serif;color:#1f2937;\">" +
                "<div style=\"max-width:560px;margin:0 auto;padding:24px;\">" +
                "<div style=\"background:#ffffff;border-radius:12px;padding:24px;border:1px solid #e5e7eb;\">" +
                "<h2 style=\"margin:0 0 12px 0;color:#0f766e;\">Tracklet SaveBuddy</h2>" +
                "<h3 style=\"margin:0 0 16px 0;\">Password reset request</h3>" +
                "<p style=\"margin:0 0 16px 0;line-height:1.5;\">We received a request to reset the password for your Tracklet SaveBuddy account.</p>" +
                "<p style=\"margin:0 0 20px 0;\"><a href=\"" + safeLink + "\" style=\"display:inline-block;background:#0f766e;color:#ffffff;text-decoration:none;padding:12px 18px;border-radius:8px;font-weight:600;\">Reset password</a></p>" +
                "<p style=\"margin:0 0 12px 0;line-height:1.5;font-size:14px;color:#374151;\">If the button does not work, copy and paste this link into your browser:</p>" +
                "<p style=\"margin:0 0 16px 0;word-break:break-all;font-size:13px;\"><a href=\"" + safeLink + "\" style=\"color:#0f766e;\">" + safeLink + "</a></p>" +
                "<p style=\"margin:0 0 12px 0;line-height:1.5;font-size:14px;\"><strong>This link expires in " + expiryMinutes + " minutes.</strong></p>" +
                "<p style=\"margin:0;line-height:1.5;font-size:14px;color:#4b5563;\">If you did not request a password reset, you can safely ignore this email. Your password will not change.</p>" +
                "</div></div></body></html>";
    }

    private String escapeHtml(String value) {
        if (value == null) return "";
        return value.replace("&", "&amp;")
                .replace("<", "&lt;")
                .replace(">", "&gt;")
                .replace("\"", "&quot;")
                .replace("'", "&#39;");
    }
}
