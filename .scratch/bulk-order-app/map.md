# Wayfinder Map: Bulk-Order E-Commerce Platform

Destination: Complete architectural and domain specification (`spec.md`), Firestore entity schemas, Cloud Functions settlement state machine, and modular Flutter client foundation with Shadcn UI and Riverpod Generator.

## Notes

- Domain: Time-windowed community bulk buying (10:00 AM – 11:59 PM daily), discrete MOQ batch buckets, wallet-mediated escrow transactions.
- Skills to consult: `domain-modeling`, `codebase-design`, `firebase-firestore`, `research`.
- Standing preferences: 
  - Strict single-bucket integrity with hard capacity limits on client quantity selection.
  - Zero client writes to financial balances or bucket tallies (all mediated via Cloud Functions transactions).
  - Idempotent wallet transactions for bKash and SSLCommerz.

## Decisions so far

- [01-bkash-sslcommerz-integration-architecture.md](issues/01-bkash-sslcommerz-integration-architecture.md): bKash Tokenized Checkout (v1.2.0-beta) execute flow and SSLCommerz (v4) IPN validation via `val_id`; atomic write-once ledger in `wallet_transactions/{gatewayTrxId}` guarantees zero double-crediting.
- [02-firestore-schema-and-security-rules.md](issues/02-firestore-schema-and-security-rules.md): Production schemas for products, daily campaigns, batch buckets, users with escrow balance separation, orders, and ledger; production firestore.rules lock client writes on catalogs, buckets, orders, and balances.
- [03-cloud-functions-bucket-transaction-engine.md](issues/03-cloud-functions-bucket-transaction-engine.md): TypeScript Cloud Functions (v2) for atomic `placeOrder` with hard capacity clamping and automatic rollover to Bucket #(N+1); scheduled 11:59 PM `settleDailyCampaign` cron job with idempotent escrow captures and batch wallet refunds.
- [04-flutter-project-scaffold-shadcn-riverpod.md](issues/04-flutter-project-scaffold-shadcn-riverpod.md): Modular feature-first Flutter client foundation with Shadcn UI (Zinc/Emerald), Riverpod state management, GoRouter shell navigation, hard capacity clamping selector, and error boundaries.
- [05-algolia-search-sync-and-riverpod-search-ui.md](issues/05-algolia-search-sync-and-riverpod-search-ui.md): Single rolling Algolia index with daily facet filters; real-time onDocumentWritten and campaign activation batch sync Cloud Functions; 300ms debounced Riverpod search UI with Shadcn popover, category chips, and live quota progress bars.
- [06-sms-otp-auth-and-customer-onboarding.md](issues/06-sms-otp-auth-and-customer-onboarding.md): Bangladeshi mobile phone SMS OTP verification with masked inputs, 60s countdown timer, automatic Firestore zero-balance customer profile creation adhering to security rules, and structured delivery address onboarding.

## Not yet specified

- Wholesale supplier procurement manifest generation (PDF / CSV export for physical procurement teams at midnight).
- Local courier API integration (Pathao / Steadfast / RedX automated parcel creation for confirmed buckets).
- Automated FCM push notification matrix (e.g. "Only 5 kg left to unlock Oranges!", "Bucket #1 confirmed!", settlement refund notifications).
- Admin dashboard interface for scheduling daily listings and reviewing manual payout/withdrawal queues.

## Out of scope

- Multi-vendor third-party marketplace seller registration (centralized procurement model only).
- Traditional instant checkout bypassing the internal wallet ledger.
- Real-time stock reservation locks without payment (items in cart do not reserve bucket capacity until paid).
