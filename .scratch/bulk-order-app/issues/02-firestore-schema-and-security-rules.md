Type: prototype
Status: open
Blocked by: None

## Question

What is the comprehensive Firestore document structure for:
1. `products` (master catalog)
2. `daily_campaigns/{date}/listings/{listingId}` and subcollection `buckets/{bucketNumber}`
3. `users/{userId}` (including `available_balance` and `escrow_balance`)
4. `orders/{orderId}` and `order_items`
5. `wallet_transactions/{trxId}` (ledger)

And what are the production Firestore Security Rules (`firestore.rules`) enforcing that clients can read catalogs and orders, but cannot directly increment/decrement bucket quantities, wallet balances, or create confirmed orders without server-side Cloud Function execution?
