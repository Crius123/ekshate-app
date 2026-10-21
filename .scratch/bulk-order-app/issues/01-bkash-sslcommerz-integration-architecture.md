Type: research
Status: resolved
Blocked by: None

## Question

What are the exact API authentication requirements, webhook callbacks, IPN flows, and signature verification patterns required for bKash Checkout (Tokenized API) and SSLCommerz Hosted Checkout when executing idempotent wallet deposits into Firebase Cloud Functions? What schema must the write-once transaction ledger (`wallet_transactions`) maintain to prevent double-crediting?

## Answer

### 1. bKash Tokenized Checkout (v1.2.0-beta)
- **Authentication**: `POST /tokenized/checkout/token/grant` using `app_key`, `app_secret`, `username`, `password`. Caches `id_token` (valid 1 hour) and uses `refresh_token` (valid 28 days) stored in Firestore / memory cache to prevent rate-limiting.
- **Payment Creation**: Cloud Function calls `POST /tokenized/checkout/create` with `payerReference` (UID), `callbackURL`, and `merchantInvoiceNumber`. Returns `bkashURL` loaded in Flutter `webview_flutter`.
- **Server Execution**: Client redirect is never trusted directly. The callback URL triggers a Cloud Function that calls `POST /tokenized/checkout/execute` with `paymentID`.
- **Query Fallback**: If network drops occur during execution, `POST /tokenized/checkout/payment/status` queries transaction state before aborting.

### 2. SSLCommerz Hosted Payment (v4)
- **Session Init**: Cloud Function calls `POST /gwprocess/v4/api.php` with `store_id`, `store_passwd`, `tran_id`, `total_amount`, `currency: 'BDT'`, `shipping_method: 'NO'`, `product_profile: 'non-physical-goods'`, `value_a: userId`, and `ipn_url`. Returns `GatewayPageURL`.
- **Server-to-Server Validation**: Dual triggers (browser redirect and asynchronous IPN webhook) must both query `https://securepay.sslcommerz.com/validator/api/validationserverAPI.php?val_id=...`. Validates `status: 'VALID' | 'VALIDATED'`, exact `amount`, `currency: 'BDT'`, and matching `tran_id`.

### 3. Write-Once Transaction Ledger & Idempotency Pattern
- **Ledger Path**: `wallet_transactions/{gatewayTrxId}` where the document ID is the gateway's unique transaction identifier (bKash's `trxID` or SSLCommerz's `val_id`).
- **Atomic Commits**: Executed inside `db.runTransaction`:
  1. Transaction reads `wallet_transactions/{gatewayTrxId}`. If it exists, aborts immediately as already processed.
  2. Creates immutable `wallet_transactions/{gatewayTrxId}` record.
  3. Executes `FieldValue.increment(amount)` on `wallets/{userId}`.
- **Security Rules**: `wallets` and `wallet_transactions` have `allow write: if false;` on client SDKs. All ledger writes are strictly confined to Cloud Functions Admin SDK.
