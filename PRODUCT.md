# Product

<!-- impeccable:product-schema 1 -->

## Platform

adaptive

## Stack

Flutter (shadcn_ui, flutter_riverpod, go_router, flutter_animate) with Firebase Cloud Functions (v2) and Cloud Firestore backend.

## Users

Urban Bangladeshi households, families, and cost-conscious grocery consumers in Dhaka and other metropolitan cities seeking genuine wholesale prices for daily commodities, staple grains (e.g. Miniket Rice), and seasonal produce (e.g. Nagpur Oranges).

## Product Purpose

Ekshate ("একসাথে" - Together) aggregates consumer purchasing power into time-windowed daily buying campaigns (10:00 AM – 11:59 PM BDT) to unlock primary wholesale market pricing (e.g. Karwan Bazar), bypassing intermediary markups through collective batch buying.

## Positioning

Unlike conventional grocery e-commerce that adds retail intermediary markups or ad-hoc social buying groups prone to manual accounting mistakes and payment risks:
- Ekshate enforces discrete batch buckets with hard capacity clamping (orders lock into fixed MOQ volume quotas, preventing bucket fragmentation).
- Orders are backed by internal wallet escrow with bKash and SSLCommerz integration.
- Automated midnight reconciliation ensures guaranteed fulfillment for unlocked buckets and instant zero-loss refunds for unfulfilled partial buckets.

## Operating Context

- **Multi-surface Adaptation**:
  - **Smartphone**: Native mobile app ergonomics (bottom navigation bar, thumb-friendly touch targets, mobile sheet dialogs, compact density).
  - **Web / Desktop**: Desktop-first web ergonomics (top persistent navigation header, wide responsive grid layouts, desktop-optimized modals, keyboard accessibility).
- **Daily Window Mechanics**:
  - *Preview Window (12:00 AM – 10:00 AM BDT)*: Read-only catalog, Algolia search, deal countdowns, wallet deposit.
  - *Active Campaign Window (10:00 AM – 11:59 PM BDT)*: Live batch purchasing, progress tracking, capacity-clamped quantity selection.
  - *Settlement Engine (11:59 PM BDT)*: Idempotent backend cron settling confirmed buckets for morning procurement and issuing instant refunds for open buckets.
- **Financial Rails**: Bangladeshi Taka (`৳`) via bKash Tokenized Checkout and SSLCommerz gateway.

## Capabilities and Constraints

- **Adaptive Navigation & Layout**: Dynamically adapt shell navigation (bottom `NavigationBar` on mobile vs top header on web/desktop) and responsive layouts across viewport breakpoints.
- **Capacity Clamped Quantity Selection**: Order quantity picker is strictly constrained to the remaining capacity of the current open bucket (`moq_threshold - current_quantity`).
- **Escrow-Protected Wallet**: Dual balances (`available_balance` and `escrow_balance`) with strict server-side transaction ledger. No client-side balance mutations.
- **Search-as-You-Type**: Debounced (300ms) Algolia search index synchronization with live bucket fill indicators.

## Brand Commitments

- **Name**: Ekshate ("একসাথে")
- **Tone & Identity**: Trustworthy, utilitarian, transparent, and community-centric grocery platform.
- **Visual & Cultural Signals**: Crisp Bengali/English bilingual clarity, authentic Bangladeshi Taka (`৳`) currency representation, clear savings callouts (wholesale vs retail price delta).

## Evidence on Hand

- Domain Glossary: `GLOSSARY.md`
- Architecture Specification: `.scratch/bulk-order-app/spec.md`
- Implementation Plan & Map: `.scratch/bulk-order-app/map.md`
- Mobile Client Codebase: `lib/` (features: `auth`, `wallet`, `catalog`, `daily_sale`, `cart`, `orders`, `procurement`, `search`, `admin`)
- Firestore Rules & Cloud Functions: `firestore.rules`, `functions/`

## Product Principles

1. **Dual-Experience Adaptation**: Feel like a native app on mobile phones and a modern website on desktop/web—never force a mobile phone layout onto a desktop browser.
2. **Transparent Collective Savings**: Explicitly display wholesale price, retail benchmark, community MOQ progress, and actual savings for every deal.
3. **Zero-Loss Guarantee**: Customer money in unfulfilled buckets is never trapped; it returns to available balance automatically at midnight.
4. **Hard Volume Quota Integrity**: Strictly enforce single-bucket ordering so community quotas remain deterministic and fulfillable.
