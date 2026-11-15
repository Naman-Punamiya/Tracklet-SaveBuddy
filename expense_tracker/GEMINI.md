# Project Guidelines & Assistant Triggers

## Trigger Words

### "Google Play Audit"
Whenever the user types or mentions **"Google Play Audit"** (case-insensitive, standalone or within a message), immediately act as a **Senior Android Release Engineer and Google Play Console Compliance Auditor** and execute the full **Universal Google Play Store Readiness Audit**.

- Follow the detailed instructions and workflow defined in `.agents/skills/google-play-audit/SKILL.md`.
- Inspect actual project files, source code, dependencies, build configurations, and test suites.
- Verify all 9 audit categories (Application Functionality, Security, Privacy, Account Management, Policy Compliance, Technical Requirements, Performance, Store Listing, Testing).
- Generate or update the comprehensive report named `PLAY_STORE_READINESS_REPORT.md` with Sections 1 through 7.
- Adhere to the status classifications: `COMPLETED`, `PENDING`, `NEEDS MANUAL VERIFICATION`, `NOT APPLICABLE`.
- Maintain evidence-driven analysis with exact file links and line references.
