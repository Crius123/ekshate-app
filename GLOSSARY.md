# Domain Glossary: Ekshate Bulk-Order Platform

This document captures the canonical domain vocabulary for the application. All specifications, Firestore data models, UI labels, and code symbols must adhere strictly to these terms.

---

### Core Concepts

#### Master Product
The permanent product entity in the system catalog (e.g., "Nagpur Oranges", "Miniket Rice"). It holds static metadata including product title, category, media assets (photos), base unit measurement (kg, piece, liter), and general description. It does not carry volatile pricing or MOQ data.

#### Daily Listing
A time-bound offering of a Master Product for a specific calendar date (e.g., `daily_campaigns/2026-10-21/listings/oranges_01`). It defines today's `unit_price`, target `moq_threshold`, and links to the active and closed `Batch Buckets` for the day.

#### Daily Window (Campaign Window)
The active daily purchasing interval: **10:00 AM to 11:59 PM (BDT)**. During this window, users can place orders into active Batch Buckets using their wallet balance.

#### Preview Window
The daily interval between **12:00 AM (midnight) and 10:00 AM (BDT)**. During this period, the previous day's orders are settled, morning procurement runs, and today's upcoming catalog is visible in read-only mode with a countdown timer. Users can browse, search via Algolia, and top up their wallets, but cannot checkout items.

#### Batch Bucket
A discrete volume quota for a Daily Listing (e.g., 100 kg per bucket). 
- A product begins the day with Bucket #1.
- Each bucket has an accumulating `current_quantity` and a fixed `moq_threshold`.
- When `current_quantity == moq_threshold`, the bucket locks as **Target Met** (guaranteed fulfillment), and Bucket #2 opens immediately with `current_quantity = 0`.
- Orders cannot span multiple buckets.

#### Remaining Bucket Capacity
The volume remaining to complete the currently open bucket (`moq_threshold - current_quantity`). The UI quantity selector is hard-clamped to this remaining capacity. Users cannot order more than what is left to close the current bucket.

#### Wallet & Wallet Escrow (Reserved Balance)
- **Available Balance:** Free funds in the user's wallet available for deposits, withdrawals, or new checkouts.
- **Escrow / Reserved Balance:** Funds deducted at checkout and held in pending state during an active Daily Window while waiting for bucket resolution.
- **Settlement:** If a bucket meets MOQ at 11:59 PM, escrowed funds are permanently transferred to revenue/order status. If a bucket fails MOQ, the exact reserved amount is instantly returned to the user's Available Balance.

#### Settlement Engine
The automated, idempotent backend reconciliation service (scheduled Cloud Function) running at 11:59 PM every night. It iterates through all Daily Listings, closes open unfulfilled buckets, marks won buckets as `confirmed`, generates supplier wholesale procurement manifests, and executes wallet refunds for unfulfilled partial buckets.

#### Idempotent Transaction Ledger
A write-once ledger in Firestore (`wallet_transactions/{trxId}`) storing payment callbacks from bKash and SSLCommerz, order debits, refunds, and withdrawal entries to guarantee zero double-spending or duplicate credits.
