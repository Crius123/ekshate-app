# 13: Local Courier Dispatch API Integration & Automated Consignment Parcel Generation (Pathao / Steadfast / RedX)

**What to build:** An automated last-mile dispatch engine and multi-courier booking adapter (Pathao Courier API v2, Steadfast, RedX) that batches all confirmed orders post-morning procurement, calculates volumetric parcel weights, registers consignments with courier endpoints, assigns tracking IDs, and updates Flutter order cards with consignment tracking pills.

**Blocked by:** 12: Wholesale Supplier Morning Procurement Manifest & Purchase Order Generator

**Status:** completed

- [x] Unified courier gateway adapter (`functions/src/courierDispatch.ts`) supporting Pathao Courier API, Steadfast Courier, and RedX with normalized booking payloads and mock mode for testing/staging.
- [x] Cloud Function `dispatchCampaignOrders` (`functions/src/courierDispatch.ts`) processes confirmed orders for a campaign date, computes parcel package weights from item quantities, and reserves consignments via courier API.
- [x] Updates order records in `orders/{orderId}`: transitions status to `dispatched`, records `courier_partner`, `consignment_id`, `tracking_code`, and `dispatched_at` timestamp.
- [x] Flutter Order Card updates (`lib/features/orders/`): renders `DISPATCHED` status badge, courier partner logo/pill, copyable tracking code, and tracking details.
- [x] Integration tests verify consignment payload construction, weight aggregation math, batch chunking, courier fallback mechanisms, and Flutter UI tracking badges.
