# 07: Wallet Hub, Dual-Balance Display & bKash / SSLCommerz Deposit Flow

**What to build:** A comprehensive digital wallet hub providing distinct visual separation between free available funds and funds locked in pending batch order escrow, backed by instant top-up via bKash Tokenized Checkout and SSLCommerz hosted payments with write-once ledger idempotency.

**Blocked by:** 06: SMS OTP Authentication & Customer Profile Onboarding

**Status:** resolved

- [x] High-fidelity Wallet screen presents two prominent summary cards: `Available Balance` (emerald) and `Escrow Balance` (amber, noting locked batch deals).
- [x] In-app bKash Tokenized Checkout flow allows customers to enter amount and triggers secure checkout session with transaction status polling.
- [x] SSLCommerz hosted payment option generates secure session redirect with IPN server callback verification.
- [x] Cloud Function handles payment callbacks by atomically verifying `wallet_transactions/{gatewayTrxId}` to guarantee zero duplicate credits before incrementing `available_balance`.
- [x] Real-time transaction history displays categorized ledger entries (`top_up`, `order_hold`, `order_settle`, `order_refund`) with timestamps and copyable transaction IDs.
- [x] Integration tests verify atomic deposit balance increments, idempotency against repeated webhooks, and ledger immutability.
