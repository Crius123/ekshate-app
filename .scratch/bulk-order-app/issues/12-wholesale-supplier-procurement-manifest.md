# 12: Wholesale Supplier Morning Procurement Manifest & Purchase Order Generator

**What to build:** A morning procurement reconciliation engine and physical purchasing manifest generator that aggregates all confirmed won buckets following the 11:59 PM settlement, compiling itemized volume quotas, supplier contact records, estimated wholesale procurement budgets, packaging specifications, and export tools for physical market agents at 4:00 AM (Karwan Bazar & farm depots).

**Blocked by:** 11: Order Tracking Dashboard & Midnight Settlement Escrow Refund Reconciliation

**Status:** completed

- [x] Cloud Function `generateProcurementManifest` (`functions/src/generateProcurementManifest.ts`) aggregates confirmed buckets for a campaign date into a centralized procurement manifest.
- [x] Manifest aggregates all confirmed buckets (`status: 'confirmed'`) across listings: calculates total confirmed volume, itemized unit quotas, total wholesale expenditure budget, and packaging requirements (e.g. 50 kg burlap bags, 10 kg crates).
- [x] Saves immutable record to `procurement_manifests/{date}` with fields: `date`, `total_confirmed_volume`, `total_procurement_cost`, `total_items_count`, `items`, and status (`pending_procurement`, `in_procurement`, `procured`).
- [x] Generates downloadable/shareable procurement CSV payload with standardized columns: `SKU`, `Product Title`, `Category`, `Total Volume`, `Unit`, `Estimated Unit Cost`, `Total Budget`, `Target Wholesale Market / Supplier`, and `Packaging Notes`.
- [x] Flutter Procurement Screen (`lib/features/procurement/`) displays morning procurement summary cards, itemized wholesale checklist with progress toggles, and 1-tap CSV export/share capability.
- [x] Integration tests verify manifest volume aggregation math, empty/zero confirmed bucket handling, Firestore document integrity, and CSV string formatting.
