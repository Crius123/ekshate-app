# 11: Order Tracking Dashboard & Midnight Settlement Escrow Refund Reconciliation

**What to build:** A comprehensive order tracking dashboard displaying active batch orders with live bucket status tooltips, paired with the scheduled 11:59 PM settlement reconciliation engine that confirms won buckets and automatically batches wallet refunds for unfulfilled partial buckets.

**Blocked by:** 10: Batch Cart, Escrow Pre-Verification & Atomic `placeOrder` Checkout

**Status:** ready-for-agent

- [ ] Orders screen organizes customer orders into filterable segmented tabs: `Active Escrow (Pending)`, `Confirmed Deals`, and `Refunded Deals`.
- [ ] Each order card displays product title, quantity, total escrow held, delivery destination, allocated bucket number, and explanatory status badge:
  - `PENDING ESCROW` (amber): Explains funds are held securely until bucket hits MOQ.
  - `CONFIRMED` (emerald): Explains bucket met MOQ and order is queued for morning procurement.
  - `REFUNDED` (red): Explains bucket did not meet MOQ and escrow was restored to available balance.
- [ ] Scheduled Cloud Function `settleDailyCampaign` (`functions/src/settleDailyCampaign.ts`) runs at 11:59 PM BDT (`59 23 * * *`, `Asia/Dhaka`).
- [ ] Settlement engine locks campaign to `settling`, confirms won buckets (`target_met`), and captures escrow.
- [ ] For partial buckets (`open`), marks bucket `failed` and executes batch refunds in chunks of 50: restores user `available_balance`, decrements `escrow_balance`, flags order as `refunded`, and writes `order_refund` ledger entries.
- [ ] Settlement engine is strictly idempotent: re-running on an already settled campaign exits with zero duplicate operations.
- [ ] Integration tests verify midnight cron execution, order status transitions, automated escrow refund math, and idempotency guards.
