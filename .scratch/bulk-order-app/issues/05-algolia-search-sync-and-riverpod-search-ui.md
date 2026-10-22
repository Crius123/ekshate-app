Type: research
Status: resolved
Blocked by: 02

## Question

How should Algolia indices be structured for daily active listings, how does a Firebase Cloud Function sync Firestore daily listings into Algolia upon campaign activation, and how should Riverpod Generator handle debounced text search queries, caching, and state transitions in Flutter with `shadcn_ui` search components?

## Answer

### 1. Algolia Index Schema for Time-Windowed Daily Deals
A **single rolling index (`ekshate_daily_listings`)** with facet filters (`status:active AND date:YYYY-MM-DD`) is established. This avoids the operational latency, dynamic index creation delays, and client configuration complexity of date-partitioned indices.

#### Index Configuration ([`functions/src/algoliaConfig.ts`](file:///f:/flutter%20projects/ekshate%20app/functions/src/algoliaConfig.ts)):
- **Searchable Attributes**: `unordered(product_title)`, `unordered(category)`, `description`, `unit`.
- **Attributes for Faceting**:
  - `filterOnly(status)` (`'preview' | 'active' | 'closed' | 'settled'`)
  - `filterOnly(date)` (Campaign date `YYYY-MM-DD`)
  - `category` (Browse facet chips)
- **Custom Ranking**:
  1. `desc(total_volume_ordered)`: Highlights deals nearest to or exceeding MOQ targets (social proof).
  2. `desc(discount_percent)`: Prioritizes maximum discount offerings.
  3. `asc(unit_price)`: Value tie-breaker.
- **Client Security**: Mobile clients connect using **Algolia Secured (Virtual) API Keys** generated via Cloud Function `getSearchToken`, hardcoded with `filters: "status:active AND date:YYYY-MM-DD"` and an expiration timestamp at 11:59:59 PM BDT.

---

### 2. Cloud Functions (v2) Real-Time & Batch Sync Engine
Implemented in [`functions/src/algoliaSync.ts`](file:///f:/flutter%20projects/ekshate%20app/functions/src/algoliaSync.ts) using the official `algoliasearch` v5 SDK:

1. **Reactive Document Sync (`syncListingToAlgolia`)**:
   - Firestore `onDocumentWritten` trigger on `daily_campaigns/{date}/listings/{listingId}`.
   - Handles `create`, `update`, and `delete` operations seamlessly.
   - Denormalizes active batch bucket metrics (`active_bucket_current_qty`, `active_bucket_remaining_capacity`, `active_bucket_progress_percent`) into the Algolia record so search result tiles render live capacity without secondary Firestore queries.
2. **Campaign Activation Batch Sync (`onCampaignActivated`)**:
   - `onDocumentUpdated` trigger on `daily_campaigns/{date}`.
   - When campaign status flips to `'active'` at 10:00 AM BDT, executes an atomic `client.saveObjects()` batch upsert of all listings for that date.
3. **Callable Token Generator (`getSearchToken`)**:
   - Authenticated callable returning scoped, short-lived Algolia search tokens for the client.

---

### 3. Flutter Riverpod Debounced Search & Shadcn UI Components
Implemented in:
- Domain model: [`lib/features/search/domain/daily_search_result.dart`](file:///f:/flutter%20projects/ekshate%20app/lib/features/search/domain/daily_search_result.dart)
- Debounced Controller: [`lib/features/search/presentation/search_controller.dart`](file:///f:/flutter%20projects/ekshate%20app/lib/features/search/presentation/search_controller.dart)
- Search Bar & Result Tile UI: [`lib/features/search/presentation/widgets/daily_search_bar.dart`](file:///f:/flutter%20projects/ekshate%20app/lib/features/search/presentation/widgets/daily_search_bar.dart)

#### Key Architectural Features:
1. **300ms Keystroke Debouncing**:
   - Handled via `ref.onDispose` and `Future.delayed(const Duration(milliseconds: 300))` in `debouncedSearchResultsProvider`. Cancels outdated in-flight requests and avoids rate-limiting Algolia API calls while typing.
2. **5-State Presentation Machine**:
   - **Idle**: Displays popular category suggestion chips (`Fruits`, `Grains`, `Oils`, `Vegetables`).
   - **Loading**: Centered emerald spinner indicator.
   - **Empty**: Contextual "No products found for [query]" empty state.
   - **Error**: Error boundary card with retry action.
   - **Success**: List of search results showing discount badges, active bucket number, live quota fill progress bar, and remaining capacity.
3. **1-Tap Quick Volume Reserve**:
   - Each search hit includes a "Quick Reserve" action that immediately validates remaining capacity and adds the item to the user's batch cart with zero page navigation.

---

### 4. Verification
- `dart analyze`: **No issues found!**
- `flutter test`: **All tests passed!**
