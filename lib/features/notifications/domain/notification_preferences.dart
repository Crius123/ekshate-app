/// User preferences for opting in/out of specific push & in-app notification types.
class NotificationPreferences {
  final bool orderUpdates;
  final bool walletAlerts;
  final bool communityDrops;

  const NotificationPreferences({
    this.orderUpdates = true,
    this.walletAlerts = true,
    this.communityDrops = true,
  });

  NotificationPreferences copyWith({
    bool? orderUpdates,
    bool? walletAlerts,
    bool? communityDrops,
  }) {
    return NotificationPreferences(
      orderUpdates: orderUpdates ?? this.orderUpdates,
      walletAlerts: walletAlerts ?? this.walletAlerts,
      communityDrops: communityDrops ?? this.communityDrops,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'orderUpdates': orderUpdates,
      'walletAlerts': walletAlerts,
      'communityDrops': communityDrops,
    };
  }

  factory NotificationPreferences.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const NotificationPreferences();
    return NotificationPreferences(
      orderUpdates: data['orderUpdates'] != false,
      walletAlerts: data['walletAlerts'] != false,
      communityDrops: data['communityDrops'] != false,
    );
  }
}
