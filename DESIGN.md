---
name: Ekshate
description: Community bulk-buying platform uniting Bangladeshi households for wholesale grocery savings
colors:
  emerald-primary: "#10b981"
  emerald-dark: "#059669"
  emerald-light: "#34d399"
  amber-escrow: "#d97706"
  sky-courier: "#0284c7"
  rose-refund: "#dc2626"
  slate-bg: "#f8fafc"
  card-surface: "#ffffff"
  card-elevated: "#f1f5f9"
  border-subtle: "#e2e8f0"
  border-highlight: "#cbd5e1"
  text-primary: "#0f172a"
  text-secondary: "#334155"
  text-muted: "#64748b"
typography:
  display:
    fontFamily: "Inter, Roboto, -apple-system, sans-serif"
    fontSize: "32px"
    fontWeight: 800
    lineHeight: 1.2
  headline:
    fontFamily: "Inter, Roboto, -apple-system, sans-serif"
    fontSize: "24px"
    fontWeight: 700
    lineHeight: 1.25
  title:
    fontFamily: "Inter, Roboto, -apple-system, sans-serif"
    fontSize: "18px"
    fontWeight: 600
    lineHeight: 1.3
  body:
    fontFamily: "Inter, Roboto, -apple-system, sans-serif"
    fontSize: "14px"
    fontWeight: 400
    lineHeight: 1.5
  label:
    fontFamily: "Inter, Roboto, -apple-system, sans-serif"
    fontSize: "12px"
    fontWeight: 600
    lineHeight: 1.3
rounded:
  sm: "6px"
  md: "8px"
  lg: "16px"
  full: "9999px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "12px"
  lg: "16px"
  xl: "20px"
  xxl: "24px"
components:
  button-primary:
    backgroundColor: "{colors.emerald-primary}"
    textColor: "{colors.card-surface}"
    rounded: "{rounded.md}"
    padding: "12px 24px"
  button-primary-hover:
    backgroundColor: "{colors.emerald-dark}"
  card-deal:
    backgroundColor: "{colors.card-surface}"
    textColor: "{colors.text-primary}"
    rounded: "{rounded.lg}"
    padding: "16px"
  card-wallet-available:
    backgroundColor: "#ecfdf5"
    textColor: "{colors.emerald-primary}"
    rounded: "{rounded.lg}"
    padding: "18px"
  card-wallet-escrow:
    backgroundColor: "#fffbeb"
    textColor: "{colors.amber-escrow}"
    rounded: "{rounded.lg}"
    padding: "18px"
---

# Design System: Ekshate

## Overview

**Creative North Star: "The Community Pantry"**

Ekshate marries the warm, dependable spirit of a shared household pantry with the precision and transparency of modern fintech. It is built to serve Bangladeshi families pooling their buying power for fresh produce and household staples. The interface avoids cold corporate minimalism on one hand and chaotic hyper-discount retail noise on the other. Instead, every screen communicates honesty, communal solidarity, and verified wholesale savings.

The visual atmosphere is clean, structured, and luminous. Fresh emerald tones celebrate community goals reached and wholesale targets met, while reassuring amber tones signify funds safely held in escrow pending bucket completion. Information density is purposefully calibrated: critical financial figures and quota progress bars are legible at an instant glance, supporting both fast mobile transactions and comfortable desktop perusal.

**Key Characteristics:**
- **Tactile Utility**: Crisp 1.2px borders, soft ambient elevation, and luminous micro-glows give interactive cards and buttons tangible substance.
- **Adaptive Ergonomics**: Feels like an intuitive native touch application on smartphones and a spacious, structured web application on desktop browsers.
- **Radical Savings Transparency**: Every listing explicitly contrasts wholesale unit price, retail market benchmark, and exact per-unit savings in Bangladeshi Taka (`৳`).
- **Clear Dual-State Escrow**: Free funds (`available_balance`) and committed funds (`escrow_balance`) are visually differentiated at all times to eliminate transactional anxiety.

## Colors

The palette balances clean slate neutrals with high-contrast emerald and amber accents, evoking agricultural freshness and disciplined financial custody.

### Primary
- **Emerald Green** (`#10B981` / `rgba(16, 185, 129, 1)`): The primary brand identifier. Used for confirmed savings, unlocked bucket milestones, primary checkout CTAs, and available wallet balance.
- **Emerald Dark** (`#059669`): Hover, active states, and high-contrast text on light tinted backgrounds.
- **Emerald Light** (`#34D399`): Subtle progress bar highlights and gradient endings.

### Secondary
- **Amber Escrow** (`#D97706`): Designates pending batch quota commitments, funds locked in escrow, and active batch orders awaiting midnight settlement. Never indicates a system warning or failure—represents money held safely.

### Tertiary
- **Sky Courier** (`#0284C7`): Indicates morning wholesale procurement, dispatch status, packaging progress, and courier delivery tracking.
- **Rose Refund** (`#DC2626`): Strictly reserved for failed bucket reconciliations, zero-loss returned funds notifications, and destructive user actions.

### Neutral
- **Slate Background** (`#F8FAFC`): Soft off-white canvas that reduces eye strain compared to harsh `#FFFFFF` backgrounds.
- **Card Surface** (`#FFFFFF`): Pure white surfaces for foreground cards, modal sheets, and dropdown menus.
- **Card Elevated** (`#F1F5F9`): Secondary card layers, quantity picker wells, and disabled state backgrounds.
- **Border Subtle** (`#E2E8F0`): Structural boundary for cards, input containers, and dividers.
- **Text Primary** (`#0F172A`): Deep slate charcoal for primary product names, amounts, and headers.
- **Text Secondary** (`#334155`): Neutral dark gray for body descriptions and supporting data.
- **Text Muted** (`#64748B`): Mid slate for unit labels, benchmark strikethroughs, and secondary metadata.

### Named Rules
**The Escrow Distinction Rule.** Available balance (`#10B981`) and Escrow balance (`#D97706`) must never share the same hue or badge treatment in any view. Escrow is always warm amber to signify temporary custody.

**The Wholesale Contrast Rule.** Every wholesale unit price must be paired with its strikethrough retail benchmark and an explicit green pill badge showing calculated savings. Wholesale prices are never displayed in isolation.

## Typography

The type system prioritizes high-legibility numerical figures, bilingual Bengali and English clarity, and unambiguous hierarchy across compact mobile viewports and spacious web viewports.

**Display Font:** Inter, Roboto, -apple-system, sans-serif  
**Body Font:** Inter, Roboto, -apple-system, sans-serif  
**Currency & Numbers:** Tabular figures with explicit Bengali Taka symbol (`৳`)

**Character:** Utilitarian, crisp, modern fintech clarity with generous x-height and sturdy numerical weights.

### Hierarchy
- **Display** (Bold 800, 32px / 2rem, line-height 1.2): Hero campaign countdowns, primary wallet balance metrics.
- **Headline** (Bold 700, 24px / 1.5rem, line-height 1.25): Screen titles, major section headers (e.g. "Today's Wholesale Listings").
- **Title** (Semi-bold 600, 18px / 1.125rem, line-height 1.3): Product titles on cards, modal titles, transaction recipient names.
- **Body** (Regular 400, 14px / 0.875rem, line-height 1.5): Product descriptions, helper text, terms, transaction audit entries (max 65ch on web).
- **Label** (Semi-bold 600, 12px / 0.75rem, line-height 1.3): Category chips, discount percentage badges, countdown units, table column headers.

### Named Rules
**The Currency Dignity Rule.** The Bangladeshi Taka symbol (`৳`) must always precede amounts with no whitespace (e.g., `৳140/kg`), rendered in bold weight with tabular figures so decimal and integer columns remain vertically aligned.

## Layout

Ekshate adopts a strictly adaptive responsive spatial architecture:

### Multi-Platform Adaptation
- **Smartphone (< 640px)**:
  - Navigation: Fixed bottom `NavigationBar` with 5 primary destinations (Daily Sale, Catalog, Batch Cart with badge, Orders, Wallet).
  - List Architecture: Single-column vertically stacked card feeds with thumb-reachable touch targets (minimum 48×48 dp).
  - Modal Sheets: Draggable bottom sheets for deposits, quantity overrides, and filters.
- **Tablet (640px – 1024px)**:
  - Navigation: Side navigation rail or top header.
  - List Architecture: 2-column responsive grid for daily listings.
- **Desktop / Web (> 1024px)**:
  - Navigation: Persistent top navigation header containing logo, category breadcrumbs, global debounced search bar, wallet quick-pill, and cart dropdown. Bottom `NavigationBar` is completely hidden.
  - Layout Grid: Center-constrained container (`max-width: 1200px`) with 3 to 4-column product cards.
  - Modals: Centered backdrop-blurred dialogs with escape-key and click-outside dismissal.

### Spacing Scale
- `xs` (4px): Micro gaps between icon and text.
- `sm` (8px): Spacing inside compact badges and tight button padding.
- `md` (12px): Inter-element spacing inside cards and list rows.
- `lg` (16px): Standard screen edge padding on mobile, standard card padding.
- `xl` (20px): Section separation and card bottom margins.
- `xxl` (24px+): Desktop column gutters and hero banners.

## Elevation & Depth

Depth in Ekshate is grounded in subtle tactile layering rather than heavy floating drop shadows.

- **Resting Cards**: Flat background (`#FFFFFF`) framed by a crisp `1.2px` solid border (`#E2E8F0`) and a soft ambient shadow (`0 3px 10px rgba(15, 23, 42, 0.04)`).
- **Elevated Modals / Drawers**: Smooth `0 12px 32px rgba(15, 23, 42, 0.10)` with backdrop blur on translucent overlay surfaces.
- **State Glows**: Active and successful surfaces emit subtle luminous halos:
  - Emerald Glow: `rgba(16, 185, 129, 0.12)` (radius 18px, spread -2px).
  - Amber Glow: `rgba(217, 119, 6, 0.12)` (radius 18px, spread -2px).

### Named Rules
**The Structural Border Rule.** No card or floating container may rely solely on elevation shadows for boundary definition. Every elevated element must carry a crisp, low-contrast 1.2px border (`#E2E8F0` or status-tinted) to ensure contrast across budget smartphone screens and high-gamut monitors.

## Shapes

- **Cards & Primary Surfaces**: `16px` border radius (`rounded.lg`), conveying modern softness while maintaining crisp structural integrity.
- **Action Buttons**: `8px` border radius (`rounded.md`), tactile and confident.
- **Badges, Tags, & Status Pills**: `6px` border radius (`rounded.sm`) for compact deal metadata, or pill-shaped (`9999px`) for category chips.
- **Quantity Steppers & Controls**: Pill-shaped squircle containers (`9999px` or `8px`) with high-contrast tactile increment/decrement buttons.
- **Avatars & Status Indicators**: Full circular shapes (`50%` / `BoxShape.circle`).

## Components

### Buttons
- **Shape**: Confident 8px rounded rectangle (`rounded.md`).
- **Primary CTA**: Emerald linear gradient (`#10B981` to `#059669`) with pure white bold text, height 48px, minimum touch target 48×48 dp.
- **Secondary / Outlined**: Pure white background, `1.2px` border (`#E2E8F0`), slate-800 text.
- **Hover / Active**: Darkens smoothly by 8-10%, slight translateY(-1px) elevation shift on desktop web.

### BulkDealCard (Signature Component)
- **Image Header**: High-resolution 180px product photography with subtle dark bottom gradient overlay (`rgba(0,0,0,0.85)`).
- **Overlaid Badges**: Discount percentage badge (`#10B981` white text) on top-left; Active Bucket badge (`#27272A` with emerald icon) on top-right; Category tag on bottom-left.
- **Pricing Section**: Bold wholesale rate (`৳140/kg`), strikethrough retail benchmark (`৳190`), and green outline savings pill (`Save ৳50/kg`).
- **Quota Progress**: Integrated `BatchQuotaIndicator` bar displaying current kilograms, target MOQ, percentage unlocked, and remaining bucket capacity.

### CapacityQuantitySelector (Signature Component)
- **Constraint Behavior**: Hard-clamped to remaining bucket capacity (`moq_threshold - current_quantity`).
- **Controls**: Tactile minus (`-`) and plus (`+`) buttons. Plus button visibly disables with an explanatory warning badge ("Bucket Quota Limit Reached") when current selection equals remaining capacity.

### Dual-Balance Wallet Cards (Signature Component)
- **Available Balance**: Tinted emerald surface (`#ECFDF5`), emerald border, white-on-emerald checkmark badge, bold green balance amount.
- **Escrow Balance**: Tinted amber surface (`#FFFBEB`), amber border, white-on-amber lock badge, bold amber balance amount with subtitle "Locked in active batch deals".

### Navigation Shell
- **Mobile**: Flutter `NavigationBar` wrapped in `NavigationBarTheme` with pure white background, emerald pill indicators, and live badges for Cart and Orders.
- **Web / Desktop**: Sticky top navbar (`height: 68px`) with logo, search field, route links, wallet balance pill, and cart icon.

## Do's and Don'ts

### Do:
- **Do** adapt the root navigation dynamically: use the bottom `NavigationBar` only on mobile phones, and render a persistent top header on web/desktop viewports.
- **Do** hard-clamp the `CapacityQuantitySelector` to `bucket.remainingCapacity` to prevent single-order bucket fragmentation.
- **Do** display calculated savings (`Save ৳XX/unit`) explicitly alongside wholesale prices.
- **Do** preserve 48×48 dp minimum touch target dimensions on all interactive mobile buttons.
- **Do** use `AppDecorations.glassCard` with structural `1.2px` borders across all cards.
- **Do** distinguish `available_balance` (emerald `#10B981`) and `escrow_balance` (amber `#D97706`) in every wallet-related view.

### Don't:
- **Don't** render a smartphone bottom navigation bar on desktop web browsers.
- **Don't** allow an order quantity to exceed the remaining capacity of the current active bucket.
- **Don't** use warning/error red colors for escrow holds—escrow is a safe, normal state represented exclusively by amber.
- **Don't** display wholesale prices without their retail benchmark comparison.
- **Don't** rely on raw floating shadows without structural borders (`#E2E8F0`).
- **Don't** omit the Bangladeshi Taka symbol (`৳`) from currency figures.
