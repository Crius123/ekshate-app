Type: prototype
Status: resolved
Blocked by: None

## Question

What is the comprehensive Firestore document structure for:
1. `products` (master catalog)
2. `daily_campaigns/{date}/listings/{listingId}` and subcollection `buckets/{bucketNumber}`
3. `users/{userId}` (including `available_balance` and `escrow_balance`)
4. `orders/{orderId}` and `order_items`
5. `wallet_transactions/{trxId}` (ledger)

And what are the production Firestore Security Rules (`firestore.rules`) enforcing that clients can read catalogs and orders, but cannot directly increment/decrement bucket quantities, wallet balances, or create confirmed orders without server-side Cloud Function execution?

## Answer

### 1. Firestore Schema & Document Structures

#### 1.1 Master Catalog (`products/{productId}`)
Permanent system catalog of master product entities. Holds static metadata and avoids volatile pricing or MOQ data (per `GLOSSARY.md`).
```typescript
interface MasterProduct {
  id: string;                    // Document ID (e.g., 'prod_orange_01')
  title: string;                 // e.g., "Nagpur Oranges (1 kg)"
  description: string;           // Detailed description and sourcing information
  category: string;              // e.g., "Fruits", "Grains", "Oils"
  unit: string;                  // Base unit of measurement: "kg" | "piece" | "liter" | "bundle"
  media_urls: string[];          // High-resolution photography URLs (max 20 items)
  thumbnail_url: string;         // Compact preview image URL
  is_active: boolean;            // Master catalog visibility toggle
  created_at: FirebaseFirestore.Timestamp;
  updated_at: FirebaseFirestore.Timestamp;
}
```

#### 1.2 Daily Campaigns, Listings & Batch Buckets
- **Campaign Root** (`daily_campaigns/{date}` where date is `YYYY-MM-DD`):
```typescript
interface DailyCampaign {
  date: string;                  // Document ID, e.g., "2026-10-21"
  status: 'preview' | 'active' | 'settling' | 'settled';
  active_from: FirebaseFirestore.Timestamp; // 10:00 AM BDT
  active_to: FirebaseFirestore.Timestamp;   // 11:59 PM BDT
  total_listings_count: number;
  created_at: FirebaseFirestore.Timestamp;
  updated_at: FirebaseFirestore.Timestamp;
}
```

- **Daily Listing** (`daily_campaigns/{date}/listings/{listingId}`):
```typescript
interface DailyListing {
  id: string;                    // Document ID (e.g., 'oranges_01')
  product_id: string;            // Reference to products/{productId}
  product_title: string;         // Denormalized title for client UI performance
  unit: string;                  // Unit: "kg" | "piece" | "liter"
  market_price: number;          // Retail benchmark price (e.g. 240 BDT)
  unit_price: number;            // Daily bulk discounted price (e.g. 180 BDT)
  discount_percent: number;      // Calculated savings percentage (e.g. 25%)
  moq_threshold: number;         // Quota volume per bucket (e.g. 100 kg)
  active_bucket_number: number;  // Current open bucket awaiting orders (starts at 1)
  total_buckets_count: number;   // Total buckets created today (incremented on rollover)
  total_volume_ordered: number;  // Cumulative quantity ordered across all buckets today
  status: 'preview' | 'active' | 'closed' | 'settled';
  created_at: FirebaseFirestore.Timestamp;
  updated_at: FirebaseFirestore.Timestamp;
}
```

- **Batch Buckets Subcollection** (`daily_campaigns/{date}/listings/{listingId}/buckets/{bucketNumber}`):
```typescript
interface BatchBucket {
  bucket_number: number;         // Document ID integer string ("1", "2", etc.)
  listing_id: string;            // Reference to parent listing
  date: string;                  // "YYYY-MM-DD"
  moq_threshold: number;         // Target capacity (e.g. 100 kg)
  current_quantity: number;      // Accumulated volume ordered so far (0 <= current_quantity <= moq_threshold)
  remaining_capacity: number;    // moq_threshold - current_quantity (hard clamp for UI quantity selector)
  status: 'open' | 'target_met' | 'failed' | 'confirmed';
  order_count: number;           // Total orders placed in this specific bucket
  target_met_at: FirebaseFirestore.Timestamp | null;
  settled_at: FirebaseFirestore.Timestamp | null;
  created_at: FirebaseFirestore.Timestamp;
  updated_at: FirebaseFirestore.Timestamp;
}
```

#### 1.3 Users & Wallet Escrow (`users/{userId}`)
Primary account model keeping personal information and financial balances in isolated fields. Document ID strictly equals `request.auth.uid`.
```typescript
interface UserProfile {
  uid: string;                   // Document ID (matches Firebase Auth UID)
  phone_number?: string;         // Bangladeshi phone number (+8801...)
  display_name?: string;         // Customer's name
  email?: string;                // Customer's optional email
  delivery_address?: string;     // Default shipping address
  role: 'customer' | 'admin';    // Role assigned on creation; immutable by client
  available_balance: number;     // Free balance in BDT (deposits/refunds add here; orders deduct here)
  escrow_balance: number;        // Funds held in escrow while batch buckets are pending
  created_at: FirebaseFirestore.Timestamp;
  updated_at?: FirebaseFirestore.Timestamp;
}
```

#### 1.4 Orders (`orders/{orderId}`)
Customer order entities. Created exclusively by server-side Cloud Function transactions (`placeOrder`).
```typescript
interface Order {
  order_id: string;              // Unique order document ID (e.g., 'ord_918231')
  user_id: string;               // Customer UID (for ownership filter queries)
  user_phone: string;            // Contact number
  date: string;                  // Campaign date "YYYY-MM-DD"
  listing_id: string;            // Reference to daily_campaigns/{date}/listings/{listingId}
  bucket_number: number;         // Target bucket number this order is allocated into
  product_id: string;            // Reference to products catalog
  product_title: string;         // Denormalized product title
  unit: string;                  // "kg" | "liter" | "piece"
  unit_price: number;            // Price in BDT at time of order
  quantity: number;              // Volume purchased (clamped to bucket remaining_capacity)
  total_amount: number;          // quantity * unit_price
  status: 'pending_bucket' | 'confirmed' | 'refunded' | 'delivered' | 'cancelled';
  delivery_address: string;      // Physical delivery destination
  created_at: FirebaseFirestore.Timestamp;
  confirmed_at?: FirebaseFirestore.Timestamp | null;
  refunded_at?: FirebaseFirestore.Timestamp | null;
}
```

#### 1.5 Write-Once Transaction Ledger (`wallet_transactions/{trxId}`)
Immutable double-entry audit ledger for financial reconciliation.
```typescript
interface WalletTransaction {
  trx_id: string;                // Document ID (gatewayTrxId or server UUID)
  user_id: string;               // Customer UID
  type: 'deposit' | 'order_hold' | 'order_settle' | 'order_refund' | 'withdrawal';
  amount: number;                // Signed or absolute amount in BDT
  status: 'initiated' | 'completed' | 'failed';
  gateway?: 'bkash' | 'sslcommerz' | 'internal';
  gateway_trx_id?: string;       // Gateway transaction reference
  order_id?: string;             // Reference to order
  listing_id?: string;           // Reference to listing
  bucket_number?: number;        // Reference to bucket
  balance_before?: number;
  balance_after?: number;
  created_at: FirebaseFirestore.Timestamp;
}
```

---

### 2. Production Security Rules (`firestore.rules`)
The complete rules file is authored and committed at [`firestore.rules`](file:///f:/flutter%20projects/ekshate%20app/firestore.rules). Key enforcement behaviors:

1. **Client Write Lockdown on Catalog and Buckets**:
   - `products`, `daily_campaigns`, `listings`, and `buckets` have `allow write: if false;`.
   - Clients can read live campaigns and bucket fill levels (`allow read: if isAuthenticated();`), but cannot directly increment or decrement `current_quantity` or `remaining_capacity`. All bucket state changes are mediated by Cloud Functions transactions.

2. **Tamper-Proof Wallet Balances on `users/{userId}`**:
   - Profile creation (`allow create: if isOwner(userId) && isValidUserCreate(userId);`) strictly enforces `available_balance == 0`, `escrow_balance == 0`, and `role == 'customer'`. Users cannot gift themselves funds or escalate privileges upon sign-up.
   - Profile updates (`allow update: if isOwner(userId) && isValidUserUpdate(userId);`) enforce that `available_balance`, `escrow_balance`, `role`, `uid`, and `created_at` are immutable by diff checks (`areImmutableFieldsUnchanged`). Only safe profile fields (`display_name`, `delivery_address`, `email`, `phone_number`, `updated_at`) can be updated.

3. **No Direct Order Injection**:
   - `orders` collection enforces `allow write: if false;`. Clients cannot insert unverified or fake orders directly. Orders are created strictly via the backend `placeOrder` Cloud Function inside an atomic Firestore transaction.
   - Customers can read only their own orders (`allow read: if isAuthenticated() && resource.data.user_id == request.auth.uid;`).

4. **Immutable Financial Ledger**:
   - `wallet_transactions` enforces `allow write: if false;`. Ledger entries can only be generated by backend Cloud Functions during verified deposits, order holds, and settlement refunds.

---

### 3. Interactive Logic Prototype
An interactive logic simulator implementing the exact schemas, atomic transitions, capacity clamping, and security attack simulations has been created at:
- [`.scratch/bulk-order-app/prototypes/firestore-schema-and-rules-demo.html`](file:///f:/flutter%20projects/ekshate%20app/.scratch/bulk-order-app/prototypes/firestore-schema-and-rules-demo.html)

This self-contained prototype covers 4 guided scenarios:
- **Scenario 1 (Bucket Completion)**: Multi-user purchases summing to 100 kg MOQ lock Bucket #1 as `target_met` and auto-initialize Bucket #2.
- **Scenario 2 (Capacity Clamp)**: Client selector clamped to remaining capacity; orders exceeding remaining bucket volume are rejected.
- **Scenario 3 (Security Attacks Defeated)**: Malicious client writes attempting to alter wallet balances, decrement bucket volumes, or forge confirmed orders trigger security permission rejections.
- **Scenario 4 (Midnight Settlement)**: Automated refunding of escrow funds back into users' available balances when an active bucket fails to meet MOQ by 11:59 PM.
