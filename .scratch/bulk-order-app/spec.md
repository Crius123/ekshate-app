# Specification: Ekshate Bulk-Order Platform
**Status**: ready-for-agent  
**Effort**: `bulk-order-app`  
**Reference Map**: `.scratch/bulk-order-app/map.md`  

---

## Problem Statement

In Bangladesh, individual consumers and households frequently overpay for staple groceries, fruits, and daily commodities because retail supply chains add multiple intermediary markups. While wholesale agricultural and commodity markets (such as Karwan Bazar) offer significant volume discounts, individual households cannot access wholesale pricing because they cannot meet high Minimum Order Quantity (MOQ) volume quotas on their own (e.g., purchasing 100 kg of oranges or 50 bags of rice). 

Simultaneously, existing e-commerce platforms either enforce instant individual checkouts at full retail price or lack a transparent, trust-preserving mechanism for collective community purchasing. When community buying is attempted manually via social media groups, it suffers from lack of payment security, manual bookkeeping errors, order fragmentation across arbitrary quantities, and agonizing delays in reconciling refunds when community volume targets fail.

---

## Solution

Ekshate is a community bulk-buying mobile platform that aggregates consumer purchasing power into time-windowed daily campaigns (10:00 AM – 11:59 PM BDT) to unlock genuine wholesale prices. 

Key solution mechanics:
1. **Discrete Batch Buckets**: Daily product listings operate with fixed volume quotas (e.g. 100 kg per bucket). A listing opens at Bucket #1; when community orders hit 100 kg, Bucket #1 locks as guaranteed fulfillment (`target_met`), and Bucket #2 opens immediately.
2. **Hard Capacity Clamping**: Orders cannot fragment across buckets. If Bucket #1 has 15 kg remaining capacity, the client interface hard-clamps quantity selection to a maximum of 15 kg, guaranteeing single-bucket atomic integrity.
3. **Wallet Escrow Protection**: Orders are paid exclusively using an internal digital wallet backed by instant bKash Tokenized and SSLCommerz deposits. Order funds are placed into `escrow_balance` while a bucket is open. If a bucket meets MOQ, funds are captured for fulfillment. If a bucket fails MOQ at 11:59 PM, the exact escrow amount is returned instantly to the customer's `available_balance`.
4. **Automated Midnight Settlement**: An idempotent reconciliation cron runs at 11:59 PM every night, closing all campaigns, confirming successful buckets for morning procurement, and processing instant batch refunds for unfulfilled partial buckets.
5. **Algolia Search-as-You-Type**: A debounced search bar powered by a real-time synchronized Algolia index allows customers to rapidly discover active daily bulk deals with live bucket fill indicators.

---

## User Stories

### User Onboarding & Profile Management
1. As a new customer, I want to sign in with my Bangladeshi mobile phone number via SMS OTP, so that I can quickly access the platform without remembering complex passwords.
2. As a customer, I want my profile document to be automatically initialized with zero balances and a customer role, so that I have a clean account state upon registration.
3. As a customer, I want to update my delivery address and display name, so that my bulk orders are delivered to the correct location.
4. As a security-conscious buyer, I want the system to ensure other users cannot see my phone number, address, or wallet balances, so that my personal and financial information remains private.

### Wallet Deposits & Financial Ledger
5. As a customer, I want to view my `available_balance` and `escrow_balance` separately, so that I clearly know which funds are free to spend and which are reserved in active batch orders.
6. As a customer, I want to deposit funds into my wallet using bKash Tokenized Checkout, so that I can add balance seamlessly without leaving the mobile app.
7. As a customer, I want to deposit funds using cards or internet banking via SSLCommerz, so that I have an alternative payment method if bKash is unavailable.
8. As a customer, I want duplicate payment callbacks or network drops to never result in double-crediting or lost funds, so that I can trust the platform's financial ledger.
9. As a customer, I want to review an audit trail of all my top-ups, order holds, settlements, and refunds with transaction IDs and timestamps, so that I can verify every balance change.

### Daily Campaign Browsing & Algolia Search
10. As a customer browsing during the Preview Window (12:00 AM – 10:00 AM), I want to view upcoming daily deals and countdown timers, so that I can plan my daily grocery purchases ahead of time.
11. As a customer during the Preview Window, I want the order checkout button to be disabled with clear opening time messaging, so that I know orders only open at 10:00 AM BDT.
12. As a customer browsing during the Active Window (10:00 AM – 11:59 PM), I want to see today's wholesale price, retail benchmark price, and percentage savings, so that I know how much money I am saving.
13. As a customer, I want to see the real-time progress bar and active bucket number for each daily listing, so that I can judge how close the community is to unlocking the wholesale target.
14. As a customer, I want to search active daily deals using a search-as-you-type search bar, so that I can instantly locate specific items like "Nagpur Oranges" or "Miniket Rice".
15. As a customer, I want search queries to be debounced by 300ms, so that the mobile app does not trigger unnecessary network requests or stutter while I type.
16. As a customer, I want search result cards to display the current bucket fill percentage and remaining capacity, so that I can make quick buying decisions directly from search results.
17. As a customer, I want a "Quick Reserve" button on search results, so that I can add items to my cart with a single tap.

### Single-Bucket Ordering & Capacity Clamping
18. As a buyer selecting an order quantity, I want the quantity picker to be hard-clamped to the remaining capacity of the currently open bucket, so that my order never gets split across multiple buckets.
19. As a buyer trying to order more than what is left in a bucket, I want to see an immediate warning banner explaining the bucket limit, so that I understand why I cannot increment further.
20. As a buyer viewing my cart, I want the system to verify that my `available_balance` covers the total order amount, so that I am notified before checkout if I need to top up.
21. As a buyer with insufficient funds, I want a one-click shortcut to bKash top-up on the cart screen, so that I can add the exact difference and complete my order without losing my cart items.
22. As a buyer placing an order, I want the checkout execution to happen inside an atomic server transaction, so that my wallet balance is deducted and bucket capacity is reserved simultaneously without race conditions.
23. As a buyer, I want an immutable hold transaction recorded in my ledger upon order placement, so that I have a timestamped receipt of funds moved into escrow.
24. As a buyer whose purchase completes the bucket MOQ (e.g. purchasing the final 20 kg of a 100 kg bucket), I want Bucket #1 to immediately lock as `target_met` and Bucket #2 to open for subsequent buyers, so that community momentum continues without interruption.

### Settlement Engine & Escrow Reconciliation
25. As a buyer who participated in a bucket that met its MOQ target, I want my order status to transition to `confirmed`, so that I know my order is guaranteed for midnight procurement and delivery.
26. As a buyer who participated in a bucket that failed to meet MOQ before 11:59 PM, I want my order status to transition to `refunded` and my escrow funds restored to `available_balance` automatically, so that my money is never stuck in an unfulfilled deal.
27. As an operator, I want the midnight settlement cron to execute automatically at 11:59 PM BDT every night, so that all daily listings and buckets are reconciled without manual intervention.
28. As an operator, I want the settlement engine to transition the campaign to `settling` status first, so that incoming orders are locked out before reconciliation starts.
29. As an operator, I want batch refunds for partial buckets to be processed in safe chunks of 50 orders, so that Firestore batch write limits are never exceeded.
30. As an operator, I want the settlement engine to be strictly idempotent, so that unexpected cron restarts or retries never issue duplicate refunds or alter settled buckets.

---

## Implementation Decisions

### Architectural Seams & Boundaries
1. **Server Authority over Financials and Buckets**:
   - Clients have zero direct write permission on `products`, `daily_campaigns`, `listings`, `buckets`, `orders`, or `wallet_transactions`.
   - Client write operations on `users/{userId}` strictly forbid mutating `available_balance`, `escrow_balance`, `role`, `uid`, or `created_at` via Firestore diff checks (`areImmutableFieldsUnchanged`).
   - All balance deductions, escrow allocations, bucket counters, order creations, and refunds are mediated strictly via Firebase Cloud Functions (v2) inside `db.runTransaction()`.

2. **Single-Bucket Volume Quota Pattern**:
   - A Daily Listing maintains one open bucket at any given moment (`active_bucket_number`).
   - An order cannot fragment across buckets. If Bucket #1 needs 10 kg to hit MOQ and a customer wants 15 kg, the client selector clamps to 10 kg. To purchase more, the customer completes Bucket #1, and then places a separate order into the newly spawned Bucket #2.

3. **Cloud Functions State Machine Prototype Snippet**:
   *(Validated from prototype `.scratch/bulk-order-app/prototypes/cloud-functions-bucket-engine-demo.html`)*
   ```typescript
   // placeOrder Core Transition:
   availableBalance -= totalCost;
   escrowBalance += totalCost;
   bucket.currentQuantity += quantity;
   bucket.remainingCapacity = bucket.moqThreshold - bucket.currentQuantity;
   
   if (bucket.currentQuantity === bucket.moqThreshold) {
     bucket.status = 'target_met';
     listing.activeBucketNumber += 1;
     initializeBucket(listing.activeBucketNumber); // Opens #(N+1)
   }
   
   // settleDailyCampaign 11:59 PM Reconciliation:
   if (bucket.status === 'target_met' || bucket.status === 'confirmed') {
     bucket.status = 'confirmed';
     user.escrowBalance -= totalCost; // Escrow captured
   } else if (bucket.status === 'open') {
     bucket.status = 'failed';
     user.escrowBalance -= totalCost;
     user.availableBalance += totalCost; // Escrow restored
     order.status = 'refunded';
   }
   ```

4. **Algolia Search Indexing Strategy**:
   - Rolling index `ekshate_daily_listings` with facet filters on `status:active` and `date:YYYY-MM-DD`.
   - Real-time Firestore sync via `onDocumentWritten` on daily listings denormalizing active bucket fill progress and remaining capacity directly onto search records.
   - 300ms keystroke debounce in Flutter Riverpod controller via `ref.onDispose` and `Future.delayed`.

5. **Flutter Client Modular Structure**:
   - Built on `shadcn_ui: ^0.57.0`, `flutter_riverpod: ^2.5.1`, `go_router: ^14.2.0`, and `intl: 0.20.2`.
   - Organized strictly by feature: `features/auth`, `features/wallet`, `features/catalog`, `features/daily_sale`, `features/cart`, `features/orders`, `features/search`.
   - Global error boundary configured via `ErrorBoundaryWidget` on `GoRouter.errorBuilder`.

---

## Testing Decisions

### What Makes a Good Test
Tests in this codebase must test **external observable behavior** across module boundaries, never private implementation mechanics or internal variables.
- **Backend Tests**: Invoke the Cloud Function with an input payload (or simulate Firestore trigger), asserting that the database documents (user balance, bucket tallies, order documents, ledger records) transitioned to the correct state and that invalid inputs produce expected error codes.
- **Frontend Tests**: Pump widgets at the screen or shell boundary, simulate user gestures (tap, enter text), and assert that the rendered UI elements (buttons disabled, error alerts, progress bars, text labels) accurately reflect the state.

### Testing Seams
1. **Seam 1: Cloud Functions Transaction Boundary (`functions/`)**
   - High-level test harness executing `placeOrder` and `settleDailyCampaign` against the Firebase Local Emulator Suite.
   - Tests verify:
     - Hard capacity clamp rejection when `quantity > remaining_capacity`.
     - Insufficient wallet balance rejection when `available_balance < totalCost`.
     - Automatic transition of bucket to `target_met` and creation of Bucket #(N+1) when MOQ is reached.
     - Scheduled settlement confirmation of won buckets and automated batch refunding of partial unfulfilled buckets.
     - Idempotency on repeated settlement calls.
2. **Seam 2: Flutter App Widget Boundary (`test/`)**
   - Widget tests wrapping screens in `ProviderScope` and `ShadApp`.
   - Tests verify:
     - `CapacityQuantitySelector` clamps quantity to `remainingCapacity` and disables increment button at limit.
     - `CartScreen` displays warning and disables checkout when cart total exceeds `wallet.available`.
     - `DailySearchBar` debounces input, renders category suggestions when idle, and renders search result tiles with bucket progress bars.

---

## Out of Scope

- Multi-vendor third-party marketplace seller registration (all procurement is centralized through Ekshate wholesale sourcing).
- Traditional instant checkout that bypasses the internal wallet and escrow ledger.
- Real-time stock reservation locks without payment (items in cart do not reserve bucket capacity until paid).
- Direct peer-to-peer wallet transfers between users.
- In-app courier tracking maps (order statuses track procurement and delivery confirmation via status pills).

---

## Further Notes

- **Timezone Standardization**: All campaign window checks (10:00 AM start, 11:59 PM close) must strictly evaluate against **Asia/Dhaka (UTC+6)** timezone regardless of the client device's local system clock.
- **Idempotency Keys**: All financial transactions must use gateway transaction IDs (`trxID` or `val_id`) as document keys in `wallet_transactions` to eliminate double-crediting risks.
