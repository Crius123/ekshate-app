Type: prototype
Status: resolved
Blocked by: 02

## Question

How should the TypeScript Firebase Cloud Functions (v2) be designed for:
1. `placeOrder`: An atomic transaction that verifies wallet balance, checks remaining bucket capacity (`remaining_capacity >= requested_quantity`), debits the wallet, reserves escrow balance, increments `bucket.current_quantity`, creates the pending order item, and locks the bucket / initializes Bucket #(N+1) if MOQ is met.
2. `settleDailyCampaign`: A scheduled 11:59 PM cron job that locks all listings, confirms orders in completed buckets, and automatically batches wallet refunds (restoring escrow to available balance) for orders in unfulfilled partial buckets.

## Answer

### 1. `placeOrder` Atomic Transaction Engine

#### Implementation Reference:
[`functions/src/placeOrder.ts`](file:///f:/flutter%20projects/ekshate%20app/functions/src/placeOrder.ts)

#### Design Architecture:
The `placeOrder` Cloud Function is implemented using Firebase Functions v2 (`onCall`) in the `asia-south1` (Mumbai) region. It wraps the entire order creation lifecycle in a single `db.runTransaction()` guaranteeing ACID properties, preventing race conditions, and enforcing single-bucket integrity.

1. **Strict Firestore Transaction Phasing (Read-Before-Write)**:
   - **Phase A (Reads)**:
     - `users/{uid}`: Validates existence and verifies that `user.available_balance >= total_amount`.
     - `daily_campaigns/{date}`: Enforces campaign `status === 'active'` (10:00 AM – 11:59 PM BDT).
     - `listings/{listingId}`: Retrieves `unit_price`, `moq_threshold`, and `active_bucket_number`.
     - `buckets/{active_bucket_number}`: Reads current fill status.
   - **Phase B (Capacity Clamp Check)**:
     - `remainingCapacity = moq_threshold - current_quantity`
     - If `requested_quantity > remainingCapacity`, transaction aborts immediately with `HttpsError('failed-precondition')`. Orders are never allowed to fragment across buckets.
   - **Phase C (Atomic Writes)**:
     1. **Wallet Escrow Hold**: Deducts `available_balance` by `total_amount` and increments `escrow_balance` by `total_amount` using `FieldValue.increment`.
     2. **Order Creation**: Writes order to `orders/{orderId}` with `status: 'pending_bucket'`.
     3. **Audit Ledger**: Writes double-entry record to `wallet_transactions/{trxId}` with `type: 'order_hold'`.
     4. **Bucket Tally Update**: Increments `bucket.current_quantity` by `quantity` and decrements `remaining_capacity`. If `new_quantity === moq_threshold`, sets `bucket.status = 'target_met'` and `target_met_at = serverTimestamp()`.
     5. **Automatic Rollover**: If MOQ is reached, initializes `buckets/{active_bucket_number + 1}` with `current_quantity = 0`, `remaining_capacity = moq_threshold`, `status = 'open'`, and updates `listings/{listingId}.active_bucket_number = nextBucketNum`.

2. **Decoupled Order Confirmation Fan-out (`onBucketTargetMet`)**:
   - When a bucket transitions to `target_met`, a reactive Firestore trigger (`onDocumentUpdated`) asynchronously queries orders in that bucket and marks them `confirmed` with `confirmed_at = serverTimestamp()`. This prevents bulk status updates from bloating the main order transaction.

---

### 2. `settleDailyCampaign` Reconciliation Engine

#### Implementation Reference:
[`functions/src/settleDailyCampaign.ts`](file:///f:/flutter%20projects/ekshate%20app/functions/src/settleDailyCampaign.ts)

#### Design Architecture:
The settlement engine runs via Firebase Functions v2 `onSchedule` set to `'59 23 * * *'` in timezone `'Asia/Dhaka'` (11:59 PM BDT). It also provides an administrative callable endpoint (`manualSettleDailyCampaign`) for manual operations or testing.

1. **Locking & Order Ingestion Cutoff**:
   - Updates `daily_campaigns/{date}.status = 'settling'`.
   - Any concurrent `placeOrder` attempt immediately fails pre-condition validation, preventing race conditions at midnight.

2. **Dual-Branch Bucket Reconciliation**:
   - **Branch 1: Won Buckets (`status === 'target_met' | 'confirmed'`)**:
     - Marks bucket `status = 'confirmed'`, `settled_at = serverTimestamp()`.
     - For each confirmed order, captures escrow: decrements `user.escrow_balance` by `total_amount` and creates a ledger entry `type: 'order_settle'`.
   - **Branch 2: Failed Buckets (`status === 'open'`)**:
     - Marks bucket `status = 'failed'`, `settled_at = serverTimestamp()`.
     - Queries all pending orders in that bucket.
     - Runs idempotent batch refunds in chunks of 50:
       1. Reverses funds: increments `user.available_balance` by `total_amount` and decrements `user.escrow_balance` by `total_amount`.
       2. Updates order `status = 'refunded'`, `refunded_at = serverTimestamp()`.
       3. Creates write-once audit entry `wallet_transactions/{trxId}` with `type: 'order_refund'`.

3. **Campaign Finalization**:
   - Updates `daily_campaigns/{date}.status = 'settled'` and records execution metrics (`confirmedBuckets`, `failedBuckets`, `refundedOrders`, `totalRefundAmount`).
   - If re-run, checks `status === 'settled'` and exits early, guaranteeing zero duplicate refunds.

---

### 3. Interactive Logic Prototype
A shareable HTML test harness simulating concurrency races, optimistic retries, rollover to Bucket #(N+1), and midnight batch refunds has been deployed at:
- [`.scratch/bulk-order-app/prototypes/cloud-functions-bucket-engine-demo.html`](file:///f:/flutter%20projects/ekshate%20app/.scratch/bulk-order-app/prototypes/cloud-functions-bucket-engine-demo.html)

### 4. Codebase Files Created
- [`functions/src/placeOrder.ts`](file:///f:/flutter%20projects/ekshate%20app/functions/src/placeOrder.ts): Complete atomic transaction and reactive bucket listener.
- [`functions/src/settleDailyCampaign.ts`](file:///f:/flutter%20projects/ekshate%20app/functions/src/settleDailyCampaign.ts): Scheduled 11:59 PM Dhaka timezone settlement cron and batch refunder.
- [`functions/src/index.ts`](file:///f:/flutter%20projects/ekshate%20app/functions/src/index.ts): Exported functions entrypoint.
- [`functions/package.json`](file:///f:/flutter%20projects/ekshate%20app/functions/package.json) & [`functions/tsconfig.json`](file:///f:/flutter%20projects/ekshate%20app/functions/tsconfig.json): Node 20 / TypeScript v5 build configuration.
- [`firebase.json`](file:///f:/flutter%20projects/ekshate%20app/firebase.json): Configured deployment manifests for Firestore rules and Cloud Functions.
