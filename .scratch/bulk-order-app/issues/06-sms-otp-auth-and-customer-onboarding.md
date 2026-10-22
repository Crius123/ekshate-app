# 06: SMS OTP Authentication & Customer Profile Onboarding

**What to build:** A seamless mobile phone authentication and profile onboarding experience for Bangladeshi customers, using mobile numbers (+8801...) and SMS OTP verification, followed by a delivery address collection screen with Shadcn UI card styling.

**Blocked by:** None (can start immediately)

**Status:** resolved

- [x] Customer enters a valid Bangladeshi mobile number (`+8801...`) and triggers SMS OTP delivery.
- [x] High-fidelity login interface features formatted phone masking, interactive OTP inputs, resend countdown timer, and loading spinner.
- [x] Firestore `users/{userId}` profile document is automatically created on first authentication with `available_balance: 0`, `escrow_balance: 0`, and `role: 'customer'`, adhering to security rules.
- [x] Profile setup screen prompts user for `display_name` and structured delivery address (`address_line`, `area`, `city`).
- [x] Error boundary handles invalid OTPs, network timeouts, and expired codes with contextual feedback.
- [x] Widget test suite verifies login submission, OTP validation, address persistence, and auth state persistence in Riverpod.
