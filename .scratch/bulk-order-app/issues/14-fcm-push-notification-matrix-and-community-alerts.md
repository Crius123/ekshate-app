# 14: Automated FCM Push Notification Matrix & Community Urgency Alerts

**What to build:** A full-lifecycle push notification engine using Firebase Cloud Messaging (FCM) that broadcasts time-sensitive community buying momentum alerts and transactional buyer notifications (bucket urgency milestones, MOQ target met, midnight settlement escrow refund receipts, and courier dispatch tracking), paired with an in-app notification center in Flutter.

**Blocked by:** 13: Local Courier Dispatch API Integration & Automated Consignment Parcel Generation

**Status:** done

- [x] Cloud Function push notification triggers (`functions/src/notificationEngine.ts`) supporting FCM topic broadcasts (`topic: listing_{listingId}`, `topic: campaign_{date}`) and direct user device tokens (`fcm_tokens/{userId}`).
- [x] Automated urgency milestone alerts ("Almost Unlocked!"): triggers when open bucket fill reaches >= 80% (e.g., "🔥 Only 10 kg left to unlock Nagpur Oranges at ৳180/kg!").
- [x] Transactional lifecycle notifications:
  - **Bucket Target Met**: Notifies all participant buyers when bucket achieves MOQ (`onBucketTargetMet`).
  - **Settlement & Escrow Refund**: Notifies buyers at midnight settlement with confirmed order confirmations or instant 100% wallet escrow refund receipts.
  - **Courier Dispatched**: Notifies buyers upon last-mile dispatch with courier partner pill, tracking code, and delivery estimates.
- [x] In-App Notification Center & Hub in Flutter (`lib/features/notifications/`):
  - In-app notification feed screen with categorized filter tabs (`All`, `Orders`, `Wallet`, `Community Drops`).
  - Unread notification counter badge in App Scaffold navigation / App Bar.
  - Interactive notification cards with deep links to Order Tracking (`/orders`), Daily Sale (`/`), or Wallet (`/wallet`).
  - Push notification preferences toggle in user profile / settings.
- [x] Comprehensive integration tests verifying FCM payload construction, trigger thresholds, idempotency to avoid alert spamming, and Flutter notification hub UI interactions.
