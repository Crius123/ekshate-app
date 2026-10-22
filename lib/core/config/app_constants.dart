/// Canonical system constants for the Ekshate Bulk-Order Platform
class AppConstants {
  AppConstants._();

  static const String appName = 'Ekshate';
  static const String appTagline = 'Community Bulk Buying Platform';

  // Currency & Formatting
  static const String currencySymbol = '৳';
  static const String currencyCode = 'BDT';

  // Campaign Time Windows (BDT / UTC+6)
  static const int previewStartHour = 0;   // 12:00 AM
  static const int activeStartHour = 10;   // 10:00 AM
  static const int activeEndHour = 23;     // 11:59 PM
  static const int activeEndMinute = 59;

  // Ledger Transaction Types
  static const String txTopUp = 'top_up';
  static const String txOrderHold = 'order_hold';
  static const String txOrderSettle = 'order_settle';
  static const String txOrderRefund = 'order_refund';

  // Order Statuses
  static const String orderPendingBucket = 'pending_bucket';
  static const String orderConfirmed = 'confirmed';
  static const String orderRefunded = 'refunded';
  static const String orderDelivered = 'delivered';
}
