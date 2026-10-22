Type: task
Status: resolved
Blocked by: None

## Question

What is the production Flutter project structure and foundational setup with `shadcn_ui`, `riverpod_generator`, `go_router`, and `flutter_animate` that establishes feature-first architecture (`features/auth`, `features/wallet`, `features/catalog`, `features/daily_sale`, `features/cart`, `features/orders`), deep routing, theming, and offline/error boundary handling?

## Answer

### 1. Established Flutter Architecture & Directory Structure
The Flutter application has been scaffolded and validated with clean feature-first architecture at the workspace root:

```
lib/
├── app.dart                                # Root ShadApp.router with Zinc/Emerald theming
├── main.dart                               # ProviderScope entrypoint
├── core/
│   ├── config/
│   │   ├── app_constants.dart              # Currency (৳ BDT), campaign windows (10:00 AM - 11:59 PM BDT)
│   │   └── theme/
│   │       └── app_theme.dart              # Shadcn UI theme definitions (ShadZincColorScheme)
│   ├── router/
│   │   ├── app_router.dart                 # GoRouter with ShellRoute navigation shell
│   │   └── route_paths.dart                # Deep-link path constants
│   ├── errors/
│   │   ├── app_exception.dart              # Typed domain exceptions (InsufficientWalletBalance, BucketCapacityExceeded)
│   │   └── error_boundary_widget.dart      # Shadcn Card error boundary with retry triggers
│   └── widgets/
│       └── app_scaffold.dart               # Persistent bottom navigation shell with live cart badge
└── features/
    ├── auth/
    │   ├── domain/user_profile.dart        # Customer profile model with isolated balance fields
    │   └── presentation/
    │       ├── auth_controller.dart        # Riverpod user state
    │       └── login_screen.dart           # Mobile number OTP sign-in
    ├── wallet/
    │   ├── domain/wallet_state.dart        # WalletTransaction audit ledger entity
    │   └── presentation/
    │       ├── wallet_controller.dart      # Dual-balance provider (available vs escrow)
    │       └── wallet_screen.dart          # bKash & SSLCommerz top-up modals and transaction log
    ├── catalog/
    │   ├── domain/product.dart             # Master catalog product entity
    │   └── presentation/
    │       └── catalog_screen.dart         # Permanent catalog browsing
    ├── daily_sale/
    │   ├── domain/
    │   │   ├── daily_listing.dart          # Discounted daily listing model
    │   │   └── batch_bucket.dart           # Discrete quota bucket model (progress %, target met check)
    │   └── presentation/
    │       ├── daily_sale_controller.dart  # Active listings & remaining capacity provider
    │       ├── daily_sale_screen.dart      # Real-time progress bars, countdown header, discount badges
    │       └── widgets/
    │           └── capacity_quantity_selector.dart # Hard-clamped quantity picker (max clamped to remainingCapacity)
    ├── cart/
    │   ├── domain/cart_item.dart           # Batch cart item with capacity limit
    │   └── presentation/
    │       ├── cart_controller.dart        # Cart modifier with funds validation
    │       └── cart_screen.dart            # Escrow checkout screen with insufficient funds warning
    └── orders/
        ├── domain/order_entity.dart        # Customer order entity
        └── presentation/
            ├── orders_controller.dart      # Orders list provider
            └── orders_screen.dart          # Order tracking (Pending Escrow, Confirmed, Refunded)
```

---

### 2. Core Dependencies & Toolchain Alignment
[`pubspec.yaml`](file:///f:/flutter%20projects/ekshate%20app/pubspec.yaml) has been configured and resolved:
- `shadcn_ui: ^0.57.0`: Production Shadcn UI widget system.
- `flutter_riverpod: ^2.5.1` & `riverpod_annotation: ^2.3.5`: Reactive state management.
- `go_router: ^14.2.0`: Deep-linking and nested shell routing.
- `flutter_animate: ^4.5.2`: Entrance and state change micro-animations.
- `intl: 0.20.2`: Pinned to match Flutter SDK `flutter_localizations`.
- `build_runner: ^2.4.9` & `riverpod_generator: ^2.4.0`: Code generation toolchain.

---

### 3. Key Enforcements Implemented

1. **Client-Side Capacity Clamping**:
   - Implemented in [`lib/features/daily_sale/presentation/widgets/capacity_quantity_selector.dart`](file:///f:/flutter%20projects/ekshate%20app/lib/features/daily_sale/presentation/widgets/capacity_quantity_selector.dart).
   - Hard clamps client selection to `remainingCapacity = moqThreshold - currentQuantity`. Disables increment when bucket quota limit is hit, preventing cross-bucket fragmentation before network request.

2. **Pre-Checkout Wallet Balance Verification**:
   - In [`lib/features/cart/presentation/cart_screen.dart`](file:///f:/flutter%20projects/ekshate%20app/lib/features/cart/presentation/cart_screen.dart), verifies `wallet.available >= cartTotal`. Displays a warning and bKash top-up shortcut if balance is insufficient.

3. **Error Boundaries & Offline Recovery**:
   - Implemented in [`lib/core/errors/error_boundary_widget.dart`](file:///f:/flutter%20projects/ekshate%20app/lib/core/errors/error_boundary_widget.dart) integrated into `GoRouter.errorBuilder`.

---

### 4. Verification
- `dart analyze`: **No issues found!**
- `flutter test`: **All tests passed!** (Smoke test at [`test/widget_test.dart`](file:///f:/flutter%20projects/ekshate%20app/test/widget_test.dart)).
