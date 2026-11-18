# Tracklet SaveBuddy — Password Reset Production Setup

This document prepares the **existing** email-based password-reset implementation for production using:
- Reset-link domain: `https://auth.namanpunamiya.me` (configurable)
- Reset endpoint/page path: `/reset-password`
- Backend API: `https://132.226.191.34` (unchanged)
- Email delivery: SMTP (environment-driven)
- Android deep links: **Android App Links** (`https://auth.namanpunamiya.me/reset-password`)

> **Important:** `namanpunamiya.me` / `auth.namanpunamiya.me` may not be permanent. The reset-link domain/base URL is configurable via environment/build configuration; do **not** hardcode it in source. Changing domains later should require configuration updates (and hosted well-known/DNS updates), not source rewrites.

---

## 1) Completed code/prep work vs manual setup required

### Completed in code/repo (no deploy/commit performed)
- **Configurable reset URL (backend):** supports `APP_PASSWORD_RESET_BASE_URL` (preferred, base domain e.g. `https://auth.namanpunamiya.me`) and derives `${base}/reset-password?token=...`; retains backward compatibility with `APP_RESET_PASSWORD_URL` (full URL) when base URL is not set. HTTPS enforcement remains in email delivery path.
- **SMTP config remains env-driven:** host/port/username/password/auth/STARTTLS/SSL/sender/from-name are read from environment/config placeholders. Missing/misconfigured delivery is handled safely and generically (no account enumeration, no token/URL logging). Existing token security, expiry, one-time-use, rate limiting, and branded HTML template preserved.
- **Android App Links prepared:** `AndroidManifest.xml` now uses configurable manifest placeholder host (`${appLinksHost}`) with `android:autoVerify="true"` for `https://<host>/reset-password` (no `example.com` hardcoded in manifest). `expense_tracker/android/app/build.gradle.kts` sets default host to `auth.namanpunamiya.me` and allows override via Gradle property or env.
- **Flutter deep-link handling:** existing `DeepLinkService` extracts reset `token` from incoming URIs and routes to reset screen without logging tokens (verified by inspection; behavior unchanged).
- **Asset Links file prepared:** `docs/.well-known/assetlinks.json` created with actual package name `com.ndevstudios.trackletsavebuddy` and a **clearly marked placeholder** SHA-256 fingerprint (must be replaced with real release/App Signing fingerprint).
- **Backend API base URL unchanged:** app/API functionality does not depend on reset domain.

### Manual setup still required (must be completed by you/infrastructure)
- Obtain SMTP provider credentials and configure environment variables/secrets.
- Configure DNS and HTTPS hosting for `auth.namanpunamiya.me` (or future domain).
- Host `/.well-known/assetlinks.json` and ensure `https://auth.namanpunamiya.me/reset-password` is publicly reachable/handled as intended.
- Obtain the **real release signing certificate SHA-256 fingerprint** (upload key or Google Play App Signing key, as applicable) and update `assetlinks.json`.
- Deploy backend/frontend hosting changes, set production env vars, and perform real end-to-end/manual verification (email delivery and App Links cannot be claimed verified without real credentials/domain/device checks).

---

## 2) Required environment variables

### Backend (Spring Boot) — set via secure environment/secret manager (never commit)

**Existing/core**
- `SPRING_DATASOURCE_URL`
- `SPRING_DATASOURCE_USERNAME`
- `SPRING_DATASOURCE_PASSWORD`
- `HEALTH_CHECK_TOKEN`

**SMTP (email delivery)**
- `SPRING_MAIL_HOST` — SMTP server hostname (from provider)
- `SPRING_MAIL_PORT` — e.g. `587` (STARTTLS) or `465` (implicit SSL), per provider
- `SPRING_MAIL_USERNAME` — SMTP username/login (from provider)
- `SPRING_MAIL_PASSWORD` — SMTP password/app password/token (from provider; secret)
- `SPRING_MAIL_SMTP_AUTH` — `true`/`false` (default `true`)
- `SPRING_MAIL_STARTTLS_ENABLE` — `true`/`false` (or legacy `SPRING_MAIL_SMTP_STARTTLS`; default `true`)
- `SPRING_MAIL_STARTTLS_REQUIRED` — `true`/`false` (set per provider security policy; default `false`)
- `SPRING_MAIL_SSL_ENABLE` — `true`/`false` (use for implicit SSL ports like 465 when required; default `false`)
- `APP_MAIL_FROM` — sender email address (must be allowed/verified by provider/domain policy)
- `APP_MAIL_FROM_NAME` — sender display name (default `Tracklet SaveBuddy`)

**Password reset link & behavior**
- `APP_PASSWORD_RESET_BASE_URL` — **preferred**, configurable HTTPS base domain, e.g. `https://auth.namanpunamiya.me` (app derives `/reset-password`)
- `APP_RESET_PASSWORD_URL` — backward-compatible **full** reset URL (used only if base URL not set)
- `APP_RESET_PASSWORD_TOKEN_EXPIRY_MINUTES` — default `20`
- `APP_RESET_PASSWORD_RATE_LIMIT_REQUESTS` — default `3`
- `APP_RESET_PASSWORD_RATE_LIMIT_WINDOW_MINUTES` — default `15`
- `APP_SECURITY_TRUST_FORWARD_HEADERS` — `true` only behind trusted reverse proxy (e.g. Nginx) that correctly sets/overwrites forwarded headers; otherwise keep `false`

**Production requirements:** reset link must resolve to a public **HTTPS** URL (non-localhost). Backend API remains `https://132.226.191.34` (separate from reset-link domain).

### Android build-time (App Links host placeholder)
- Gradle property: `-PappLinksHost=auth.namanpunamiya.me` (or future domain)
- OR environment variable: `APP_LINKS_HOST=auth.namanpunamiya.me`
- Default (if unset): `auth.namanpunamiya.me` (configured in `expense_tracker/android/app/build.gradle.kts`)

> Keep the Android App Links host aligned with the domain used in `APP_PASSWORD_RESET_BASE_URL` / hosted reset links.

---

## 3) SMTP configuration instructions

1. Choose/configure an SMTP-capable email provider or mail service (not selected here). Obtain host, port, username, password/app credential, TLS/SSL requirements, and an allowed sender address.
2. Verify/authenticate your sending domain/address as required by the provider (SPF/DKIM/DMARC recommended by provider) to improve deliverability.
3. Set backend env vars (`SPRING_MAIL_*`, `APP_MAIL_FROM`, `APP_MAIL_FROM_NAME`) in the target environment secrets/config. Use placeholders in docs/examples only.
4. Ensure `APP_PASSWORD_RESET_BASE_URL=https://auth.namanpunamiya.me` (or chosen HTTPS domain) is set so emails contain a valid, production-safe reset link.
5. **Security/behavior expectations (preserved):**
   - No credentials/tokens/reset URLs in logs or Git.
   - Missing/failed delivery must not leak account existence and must not leave misleading token state.
   - Generic forgot-password API response remains unchanged.
   - Token hashing, expiry, one-time-use, and rate limiting remain enabled.

**Do not claim email delivery works until tested with real credentials and a real inbox.**

---

## 4) DNS and hosting requirements

`auth.namanpunamiya.me` must serve public HTTPS content for App Links and reset-link handling.

### Required public URLs
- `https://auth.namanpunamiya.me/.well-known/assetlinks.json` (JSON, publicly accessible over HTTPS, correct content-type recommended `application/json`)
- `https://auth.namanpunamiya.me/reset-password` (HTTPS page/route used by reset emails; should support opening app via App Link when installed/verified and provide an appropriate fallback experience if needed)

### DNS records (examples; choose based on your hosting provider)
- **If hosting `auth` on a separate host/CDN/static site:** create a DNS record for `auth` pointing to that host:
  - `CNAME` `auth` → `<your-hosting-target>` (preferred when supported), **or**
  - `A` / `AAAA` `auth` → hosting IPv4/IPv6 address(es)
- **If proxied through a CDN/reverse proxy:** follow provider-specific DNS/proxy requirements and ensure origin serves the required paths.
- Keep DNS TTL reasonable for future domain changes (domain may not be permanent).

> Do not modify DNS/hosting in this repo/task; apply records in your DNS provider.

### HTTPS configuration
- Provision a valid TLS certificate for `auth.namanpunamiya.me` (e.g. via your host/CDN/Let’s Encrypt or managed certs).
- Enforce HTTPS (HTTP should redirect to HTTPS).
- Ensure no mixed-content or certificate errors; Android App Links verification requires a valid, trusted HTTPS host.

### Where to host `assetlinks.json`
- Host the prepared file at: `https://auth.namanpunamiya.me/.well-known/assetlinks.json`
- Repo-prepared source: `docs/.well-known/assetlinks.json` (copy/deploy this content to your web host; replace placeholder fingerprint first for production verification).
- Ensure `/.well-known/` is not blocked by auth, redirects that break verification, or rewrite rules.

### Verify public accessibility
- `curl -i https://auth.namanpunamiya.me/.well-known/assetlinks.json` returns `200` with valid JSON and correct package/fingerprints.
- `curl -I https://auth.namanpunamiya.me/reset-password` returns reachable HTTPS response (and desired behavior for browser/app-link fallback).
- Check in browser and from external network (not only localhost).

---

## 5) Android App Links setup

### App/configuration (prepared)
- Package name: `com.ndevstudios.trackletsavebuddy`
- Intent filter (main manifest): HTTPS App Link, `autoVerify="true"`, host `${appLinksHost}`, path prefix `/reset-password`
- Host placeholder default/override: `build.gradle.kts` (`appLinksHost`, default `auth.namanpunamiya.me`, override `-PappLinksHost` or `APP_LINKS_HOST`)

### Digital Asset Links
1. Replace `REPLACE_WITH_RELEASE_SIGNING_CERT_SHA256_FINGERPRINT` in `docs/.well-known/assetlinks.json` with the **actual** SHA-256 cert fingerprint(s) for the signing key used by installs you want verified (release and/or Play App Signing as applicable).
2. Host file at `https://auth.namanpunamiya.me/.well-known/assetlinks.json`.
3. Rebuild/reinstall app after manifest/assetlinks changes when testing verification.

### Release signing fingerprint instructions (required; not invented)
Obtain the correct SHA-256 fingerprint from the **actual** signing certificate used for distributed builds:

- **Local/upload keystore (if you sign APK/AAB yourself):**
  - `keytool -list -v -keystore <your-release-keystore.jks|keystore> -alias <your-key-alias>`
  - Copy the **SHA-256** certificate fingerprint and format as colon-separated uppercase pairs if needed (Android accepts standard colon format; keep consistent).
- **Google Play App Signing (if enabled):**
  - In Play Console: app → **Test and release** (or **Setup**) → **App integrity** / **App signing** → copy the **App signing key certificate** SHA-256 fingerprint (and include upload key fingerprint if you also test locally signed artifacts, as appropriate).
- **Debug builds (local testing only):** debug keystore fingerprint differs from release; production verification must use the release/Play App Signing fingerprint.

> Until the real fingerprint is set and hosted, Android App Links auto-verification will not fully succeed in production.

---

## 6) Manual email-delivery testing procedure

1. Deploy/configure backend with real SMTP env vars and `APP_PASSWORD_RESET_BASE_URL=https://auth.namanpunamiya.me` (HTTPS).
2. Trigger `POST /api/users/forgot-password` for an existing test account email.
3. Confirm API returns generic success response (no enumeration) regardless of outcome details.
4. Verify email arrives in inbox (and spam/junk if needed), branded content renders, and link points to `https://auth.namanpunamiya.me/reset-password?token=...`.
5. Confirm link/token are not exposed in application logs; do not log SMTP secrets.
6. Negative checks: missing SMTP config or forced delivery failure must not leak account existence and must not leave misleading token state (as covered by automated tests; validate behavior in environment as applicable).

---

## 7) End-to-end password-reset testing procedure

1. **Request reset:** from app Forgot Password screen (or API), submit valid email; expect generic success UI/message.
2. **Open link:** tap emailed link on Android device with app installed (after App Links verification/DNS/assetlinks configured) and confirm app opens reset screen with token; also test browser/fallback behavior as designed.
3. **Reset password:** submit valid new password (min 8 chars, at least one letter and one number) and confirm success + login with new password works (HTTP Basic auth unchanged).
4. **Security cases:** expired token, reused token, invalid token, and invalid password show appropriate errors and allow requesting a new reset.
5. **Regression checks:** existing login, authenticated flows, and **account deletion** remain unaffected.
6. **Proxy/rate limiting (if behind Nginx):** set `APP_SECURITY_TRUST_FORWARD_HEADERS=true` only with trusted proxy header sanitization and verify expected client-IP behavior.

---

## 8) Production deployment checklist

- [ ] Set all required backend env vars/secrets (DB, SMTP, reset base URL, rate limits, trust-forward-headers as appropriate). No secrets in Git.
- [ ] Confirm `APP_PASSWORD_RESET_BASE_URL` is public **HTTPS** and correct domain/path (`/reset-password` derived).
- [ ] Configure DNS + valid TLS for `auth.namanpunamiya.me`.
- [ ] Host `/.well-known/assetlinks.json` with **real** release/Play App Signing SHA-256 fingerprint(s).
- [ ] Ensure `https://auth.namanpunamiya.me/reset-password` is reachable and behaves correctly for app-link + fallback needs.
- [ ] Build Android with correct App Links host (`-PappLinksHost` / `APP_LINKS_HOST` aligned to domain).
- [ ] Verify SMTP delivery manually (real credentials) and full reset flow on device.
- [ ] Verify App Links association/verification on device (install, open link, check behavior).
- [ ] Confirm DB schema for `password_reset_tokens` exists/matches in production (Hibernate-managed or applied SQL migration as per environment).
- [ ] Reconfirm rate limiting/proxy trust settings for deployed topology (single-instance in-memory limiter limitation acknowledged).

---

## 9) Notes on configurability and constraints

- Reset-link domain/base URL is environment/build configurable; avoid hardcoding future domain values in source.
- Backend API remains `https://132.226.191.34`; ordinary app functionality must not depend on reset-link domain availability except password-reset email/link flow.
- No new migration framework introduced; no auth/account-deletion/unrelated feature changes; no deployment performed by this task.
