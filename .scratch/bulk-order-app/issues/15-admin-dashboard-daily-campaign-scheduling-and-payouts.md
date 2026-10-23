# 15: Admin Dashboard Interface for Daily Campaign Scheduling & Operator Financial Review

**What to build:** An administrative control panel and operator dashboard (`lib/features/admin/` & `functions/src/adminManagement.ts`) enabling platform operations staff to schedule tomorrow's daily wholesale listings with MOQ thresholds and pricing, monitor real-time campaign bucket momentum, trigger emergency manual settlement/dispatch cutovers, and review/approve customer wallet withdrawal requests.

**Blocked by:** 14: Automated FCM Push Notification Matrix & Community Urgency Alerts

**Status:** complete

- [x] Cloud Function admin operations API (`functions/src/adminManagement.ts`) with strict admin authorization checks (`users/{uid}.role == 'admin'`), supporting:
  - `createOrUpdateDailyCampaign`: Provisioning calendar date campaigns, setting active windows (10:00 AM – 11:59 PM BDT), and publishing wholesale listings with auto-initialized Bucket #1.
  - `reviewWithdrawalRequest`: Approving or rejecting customer wallet withdrawal/refund requests with immutable ledger accounting (`type: withdrawal_payout`).
  - `getAdminOperationalMetrics`: Real-time summary of today's GMV, escrow volume, active bucket fill percentages, and pending courier dispatch counts.
- [x] Role-based access control & navigation:
  - Role guard in GoRouter protecting `/admin` routes; only users with `role == 'admin'` can access.
  - Quick-switch or dedicated entry point in user profile for administrators.
- [x] Admin Dashboard UI in Flutter (`lib/features/admin/presentation/`):
  - **Overview & Operational Monitor**: Real-time GMV, escrow holds, campaign progress gauges, and settlement status indicators with manual override shortcuts.
  - **Daily Deal Scheduler Tab**: Form to schedule new listings for any calendar date (Product Title, Unit, Market Benchmark Price, Bulk Discount Price, MOQ Threshold, category, and hero image), automatically computing savings percentage.
  - **Wallet Withdrawal & Payouts Tab**: Queue of customer withdrawal requests with bKash/bank account details, one-tap "Approve & Payout" or "Reject with Reason", updating wallet balances atomically.
- [x] Comprehensive unit and integration test suite in TypeScript and Flutter covering admin authorization guards, campaign listing creation, withdrawal approval ledger transitions, and dashboard widget interactions.
