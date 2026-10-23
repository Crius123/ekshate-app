# 16: End-to-End Lifecycle Acceptance & Automated Smoke Test Suite

**What to build:** A comprehensive end-to-end (E2E) cross-lifecycle acceptance suite (`functions/src/test/e2eLifecycle.test.ts` and `test/integration/e2e_bulk_buying_lifecycle_test.dart`) executing the complete customer and operator journey across all 15 discrete system modules.

**Blocked by:** 15: Admin Dashboard Interface for Daily Campaign Scheduling & Operator Financial Review

**Status:** ready-for-agent

- [ ] Complete Backend E2E Lifecycle Simulation (`functions/src/test/e2eLifecycle.test.ts`):
  - **Phase 1: Deal Scheduling**: Admin provisions a daily wholesale listing (100 kg MOQ at ৳120/kg, benchmark ৳180/kg) with auto-initialized Bucket #1.
  - **Phase 2: Customer Onboarding & Wallet Top-up**: Multiple customers (User A, User B, User C) onboard and deposit funds via bKash & SSLCommerz with idempotent ledger verification.
  - **Phase 3: Community Bulk Ordering & Hard Clamping**:
    - User A orders 60 kg (Bucket #1 at 60%).
    - User B orders 25 kg (Bucket #1 at 85% -> triggers 80% urgency alert milestone).
    - Hard capacity clamping prevents User C from exceeding remaining 15 kg capacity in a single order.
    - User C orders remaining 15 kg -> Bucket #1 hits MOQ exactly (`target_met`), sends `onBucketTargetMet` notifications, and auto-spawns Bucket #2.
    - User D orders 20 kg into Bucket #2 (partial fill).
  - **Phase 4: Midnight Settlement Reconciliation**:
    - `settleDailyCampaign` transitions campaign to `settling`.
    - Bucket #1 confirmed -> escrow captured, orders confirmed.
    - Bucket #2 failed -> escrow released, User D 100% refunded to `available_balance` with write-once ledger record.
  - **Phase 5: Morning Procurement & Manifest Export**:
    - `generateProcurementManifest` aggregates confirmed Bucket #1 items, validates packaging specs, and outputs RFC 4180 CSV.
  - **Phase 6: Multi-Courier Last-Mile Dispatch**:
    - `dispatchCampaignOrders` calculates parcel weight and assigns Pathao/Steadfast/RedX tracking codes to confirmed orders.
  - **Phase 7: Operator Financial Review & Payout**:
    - User D submits withdrawal request for ৳2,400 to bKash.
    - Admin reviews, approves, debits wallet balance, and writes `withdrawal_payout` ledger entry.

- [ ] Flutter Unified Acceptance Integration Suite (`test/integration/e2e_bulk_buying_lifecycle_test.dart`):
  - Simulates the full customer lifecycle inside Flutter app widgets with Riverpod:
    - Customer mobile OTP authentication and profile setup.
    - Digital wallet deposit via bKash dialog and available balance update.
    - Daily Sale feed browsing, capacity-clamped quantity picker interaction, and batch cart reserve.
    - Order tracking dashboard viewing active escrow status (`PENDING ESCROW`).
    - Campaign settlement state updates reflecting `CONFIRMED` deal and `DISPATCHED` courier status with tracking pill.
    - Admin dashboard access, metrics inspection, deal scheduler form submission, and withdrawal payout review.

- [ ] Smoke & Regression Suite Verification:
  - All unit, widget, and E2E acceptance tests pass cleanly without race conditions or memory leaks.
