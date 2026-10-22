# 09: Real-Time Algolia Search-as-You-Type with Live Bucket Progress & Quick Reserve

**What to build:** An instant, debounced search experience on the daily sale screen powered by a synchronized Algolia index, allowing customers to search deals by name or category, view live bucket fill metrics in search results, and reserve volume with a 1-tap quick action.

**Blocked by:** 08: Daily Sale Screen with Live Batch Quota Indicators & Capacity-Clamped Quantity Picker

**Status:** ready-for-agent

- [ ] Search input features leading search icon, trailing clear button, and category suggestion chips (`Fruits`, `Grains`, `Oils`, `Vegetables`) displayed in an Idle popover state.
- [ ] Keystroke debouncing (300ms) prevents unnecessary network requests during rapid typing using `ref.onDispose` cancellation in Riverpod.
- [ ] Search hits render product title, price savings, active bucket number, and live batch quota progress bar derived directly from denormalized Algolia records.
- [ ] Each search hit includes a 1-tap "Quick Reserve (1 unit)" button that validates remaining bucket capacity and immediately inserts into the batch cart.
- [ ] Five clean UI states (Idle, Loading, Success, Empty, Error) handle offline networks and missing results gracefully.
- [ ] Cloud Function triggers (`onDocumentWritten` and `onCampaignActivated`) keep Algolia records updated as Firestore listings and buckets mutate.
- [ ] Widget and unit tests verify 300ms debouncing, empty state rendering, and Quick Reserve cart dispatch.
