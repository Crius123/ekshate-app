# 08: Daily Sale Screen with Live Batch Quota Indicators & Capacity-Clamped Quantity Picker

**What to build:** An engaging, high-fidelity daily sale discovery feed showcasing active wholesale deals, synchronized countdown timers for campaign windows, real-time batch bucket quota fill bars, and an interactive micro-animated quantity picker strictly clamped to remaining bucket capacity.

**Blocked by:** 06: SMS OTP Authentication & Customer Profile Onboarding

**Status:** resolved

- [x] Campaign header displays dynamic countdown timer reflecting campaign status: Countdown to 10:00 AM BDT (Preview Mode) or Countdown to 11:59 PM BDT (Active Ordering).
- [x] High-fidelity bulk deal cards feature high-resolution product photography, wholesale unit price (`৳180/kg`), retail benchmark strike-through (`৳240`), and percentage discount badge.
- [x] Real-time batch quota indicator renders current volume versus MOQ threshold (`65/100 kg ordered`) with an animated emerald progress bar and active bucket badge (`Bucket #1`).
- [x] Interactive `CapacityQuantitySelector` hard-clamps quantity strictly between 1 unit and `remainingCapacity`, disabling the plus button and showing a warning pill when capacity limit is reached.
- [x] "Reserve Volume" button adds the selected volume to the customer's batch cart with instant haptic and toast confirmation.
- [x] Widget tests assert correct countdown formatting, live progress bar calculation, and hard capacity limit enforcement.
