Type: prototype
Status: open
Blocked by: 02

## Question

How should the TypeScript Firebase Cloud Functions (v2) be designed for:
1. `placeOrder`: An atomic transaction that verifies wallet balance, checks remaining bucket capacity (`remaining_capacity >= requested_quantity`), debits the wallet, reserves escrow balance, increments `bucket.current_quantity`, creates the pending order item, and locks the bucket / initializes Bucket #(N+1) if MOQ is met.
2. `settleDailyCampaign`: A scheduled 11:59 PM cron job that locks all listings, confirms orders in completed buckets, and automatically batches wallet refunds (restoring escrow to available balance) for orders in unfulfilled partial buckets.
