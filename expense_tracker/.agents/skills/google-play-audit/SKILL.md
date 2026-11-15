---
name: google-play-audit
description: >-
  Triggered when the user says "Google Play Audit" or asks for an Android release readiness audit.
  Performs a comprehensive, evidence-driven Google Play Store publication and compliance audit.
---

# Universal Google Play Store Readiness Audit

Act as a Senior Android Release Engineer and Google Play Console Compliance Auditor.

When the user says "Google Play Audit" (or requests a Play Store readiness audit), perform a comprehensive audit of the current project and determine whether it is ready for publication on the Google Play Store.

This audit must work regardless of the technology used, including:
- Flutter
- Native Android (Kotlin/Java)
- React Native
- Other Android application frameworks

---

## 1. Important Instructions

1. Inspect the actual project files, source code, dependencies, configuration files, and documentation.
2. Do not assume a feature is implemented just because its name appears in the code.
3. Verify implementation wherever possible.
4. Do not modify, delete or create changes to existing application code during audit.
5. Do not claim that a requirement is completed without evidence.
6. Identify the exact file or configuration that supports each finding.
7. If something cannot be verified through source-code inspection, mark it as `NEEDS MANUAL VERIFICATION`.
8. Consider current Google Play policies and requirements (e.g. Target SDK mandates, Account Deletion policy, Data Safety, 20-tester requirement for personal accounts).
9. Do not expose secrets, passwords, API keys or signing credentials in the report.

---

## 2. Audit Categories

Audit the following 9 categories systematically:

### A. Application Functionality
- Main application features work.
- Authentication and authorization work.
- Navigation works.
- Forms and validation work.
- Error handling exists.
- Loading states are handled.
- Empty states are handled.
- No obvious incomplete features.
- No obvious debug-only functionality in production.
- Offline functionality works if advertised.
- Data synchronization works if advertised.

### B. Application Security
- HTTPS is used for production API communication.
- No hardcoded production secrets.
- Authentication tokens are handled securely.
- Sensitive information is not unnecessarily logged.
- Backend authorization is implemented.
- User data is isolated between accounts.
- Database access is appropriately protected.
- Third-party dependencies are reviewed.
- Sensitive local data is protected where appropriate.

### C. Privacy and Data Protection
- Identify all personal data collected.
- Identify financial, health, location or other sensitive data where applicable.
- Identify local storage mechanisms.
- Identify remote storage mechanisms.
- Identify third-party SDKs and services.
- Identify analytics and advertising SDKs.
- Identify information transmitted to external services.
- Check whether a privacy policy exists.
- Check whether the privacy policy is accessible.
- Check whether the policy accurately describes actual data handling.
- Check data retention and deletion mechanisms.

### D. Account Management
- Account creation works.
- Login works.
- Logout works.
- Password reset works, if supported.
- Account deletion is implemented if accounts can be created.
- Associated user data deletion is handled.
- External account deletion request webpage is available where required.
- Account deletion does not merely deactivate accounts.

### E. Google Play Policy Compliance
- Privacy policy requirements.
- Data Safety declaration requirements.
- Account deletion requirements.
- Permissions policy.
- Advertising declaration.
- Target audience declaration.
- Content rating questionnaire.
- Financial services policy, if applicable.
- User-generated content policy, if applicable.
- Families policy, if applicable.
- Health policy, if applicable.
- User data policy.
- Intellectual property and impersonation concerns.
- App access and reviewer credentials.
- Other applicable Google Play policies.
*Only mark policies relevant to the application's actual functionality.*

### F. Android Technical Requirements
- Application package ID.
- Minimum SDK version.
- Target SDK version.
- Compile SDK version.
- Android version compatibility.
- Application version name.
- Application version code.
- Release build configuration.
- Android App Bundle support.
- Release signing configuration.
- Debug configuration excluded from production.
- Internet and network permissions.
- Unnecessary permissions.
- Native library compatibility, if applicable.
- 64-bit compatibility where applicable.
- No obvious build configuration errors.
*Check current Google Play target API requirements.*

### G. Performance and Stability
- No obvious crash-prone code.
- No obvious memory leaks.
- No unnecessary background services.
- No excessive network requests.
- No blocking operations on the UI thread.
- Appropriate loading and error handling.
- Proper handling of connectivity loss.
- Proper handling of server downtime.
- Appropriate database and storage handling.
- App launch and navigation performance.

### H. Store Listing Requirements
- Application name.
- Short description.
- Full description.
- Application icon.
- Feature graphic.
- Phone screenshots.
- Tablet screenshots, if applicable.
- Support email.
- Developer contact information.
- Privacy policy URL.
- App category.
- Content rating.
- Ads declaration.
*Identify missing assets and listing information.*

### I. Testing Requirements
- Unit tests.
- Integration tests.
- UI tests.
- Authentication tests.
- API tests.
- Offline tests.
- Synchronization tests.
- Different screen-size tests.
- Different Android-version tests.
- Release build tested.
- Pre-launch report reviewed.
- Closed testing completed where required.
- Required tester count and duration verified against current Google requirements.

---

## 3. Status Classification

Every individual requirement must receive exactly one status:
- **COMPLETED**: Verified through code, configuration, tests, or reliable evidence.
- **PENDING**: Clearly missing or incorrectly implemented.
- **NEEDS MANUAL VERIFICATION**: Cannot be verified from the project source alone.
- **NOT APPLICABLE**: The requirement does not apply to this application's functionality.

---

## 4. Output Format

Generate a comprehensive report named:
`PLAY_STORE_READINESS_REPORT.md`

The report must contain:
- **Section 1: Project Overview**: Name, technology, package ID, min SDK, target SDK, version name, version code, backend tech, main features.
- **Section 2: Executive Summary**: Total requirements checked, completed, pending, needs manual verification, not applicable, overall readiness assessment.
- **Section 3: Detailed Checklist**: Markdown table with columns: `ID | Category | Requirement | Status | Evidence | Recommended Action`.
- **Section 4: Critical Blockers**: Prioritized by Critical, High, Medium, Low.
- **Section 5: Manual Verification**: Step-by-step instructions for Console, backend, and physical device checks.
- **Section 6: Recommended Fix Order**: Prioritized implementation plan (What is missing, Why it matters, Which files need changes, Suggested implementation, How to verify).
- **Section 7: Final Release Assessment**: Standard verdict (`NOT READY: Critical requirements are missing`, `NOT READY: High-priority requirements need attention`, `CONDITIONALLY READY: Code audit is satisfactory, but manual verification remains`, or `READY FOR SUBMISSION`).
