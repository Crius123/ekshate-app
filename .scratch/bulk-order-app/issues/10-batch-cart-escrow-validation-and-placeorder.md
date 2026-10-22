# 10: Batch Cart, Escrow Pre-Verification & Atomic `placeOrder` Checkout

**What to build:** An escrow-protected cart and checkout experience that verifies wallet balance against required funds, offers an instant bKash top-up shortcut for balance deficits, and executes order placement through the atomic `placeOrder` Cloud Function with automatic bucket rollover upon MOQ completion.

**Blocked by:** 07: Wallet Hub, Dual-Balance Display & bKash / SSLCommerz Deposit Flow, 08: Daily Sale Screen with Live Batch Quota Indicators & Capacity-Clamped Quantity Picker

**Status:** ready-for-agent

- [ ] Batch Cart screen displays all reserved items, unit prices, selected volumes, subtotal, and delivery address review.
- [ ] Cart summary contrasts `Total Escrow Required` against customer's `Available Balance`.
- [ ] If available balance is insufficient, checkout button is disabled and an alert banner shows the deficit with a 1-tap "Top-up via bKash" button.
- [ ] Tapping "Confirm & Escrow Funds" calls the atomic `placeOrder` Cloud Function (`functions/src/placeOrder.ts`) in `asia-south1`.
- [ ] Cloud Function executes atomic transaction: verifies funds, verifies remaining bucket capacity, debits available balance, credits escrow balance, creates `orders/{orderId}` record, writes audit ledger entry, updates bucket current quantity, and automatically rolls over to Bucket #(N+1) if MOQ is met.
- [ ] Cart clears upon successful submission and redirects customer to the Orders tab with a celebratory toast.
- [ ] Firebase Emulator integration tests verify balance deductions, capacity clamp rejection on race conditions, and automatic bucket rollover.
