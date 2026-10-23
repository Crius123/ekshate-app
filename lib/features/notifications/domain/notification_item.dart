/// Notification categories supported by the Ekshate notification system.
enum NotificationCategory {
  all,
  orders,
  wallet,
  communityDrops;

  String get label {
    switch (this) {
      case NotificationCategory.all:
        return 'All';
      case NotificationCategory.orders:
        return 'Orders';
      case NotificationCategory.wallet:
        return 'Wallet';
      case NotificationCategory.communityDrops:
        return 'Community Drops';
    }
  }

  static NotificationCategory fromString(String? value) {
    switch ((value ?? '').toLowerCase().trim()) {
      case 'orders':
      case 'order':
        return NotificationCategory.orders;
      case 'wallet':
        return NotificationCategory.wallet;
      case 'community':
      case 'community_drops':
      case 'communitydrops':
        return NotificationCategory.communityDrops;
      default:
        return NotificationCategory.orders;
    }
  }

  String get firestoreKey {
    switch (this) {
      case NotificationCategory.all:
        return 'all';
      case NotificationCategory.orders:
        return 'orders';
      case NotificationCategory.wallet:
        return 'wallet';
      case NotificationCategory.communityDrops:
        return 'community';
    }
  }
}

/// Represents an in-app and push notification record.
class NotificationItem {
  final String id;
  final String userId;
  final String title;
  final String body;
  final NotificationCategory category;
  final bool isRead;
  final String? deepLink;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  const NotificationItem({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.category,
    this.isRead = false,
    this.deepLink,
    this.metadata = const {},
    required this.createdAt,
  });

  NotificationItem copyWith({
    String? id,
    String? userId,
    String? title,
    String? body,
    NotificationCategory? category,
    bool? isRead,
    String? deepLink,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      body: body ?? this.body,
      category: category ?? this.category,
      isRead: isRead ?? this.isRead,
      deepLink: deepLink ?? this.deepLink,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'body': body,
      'category': category.firestoreKey,
      'is_read': isRead,
      if (deepLink != null) 'deep_link': deepLink,
      'metadata': metadata,
      'created_at': createdAt,
    };
  }

  factory NotificationItem.fromFirestore(Map<String, dynamic> data, String id) {
    DateTime parseDate(dynamic val) {
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      try {
        return (val as dynamic).toDate() as DateTime;
      } catch (_) {
        return DateTime.now();
      }
    }

    return NotificationItem(
      id: (data['id'] as String?) ?? id,
      userId: (data['user_id'] as String?) ?? '',
      title: (data['title'] as String?) ?? '',
      body: (data['body'] as String?) ?? '',
      category: NotificationCategory.fromString(data['category'] as String?),
      isRead: (data['is_read'] as bool?) ?? false,
      deepLink: data['deep_link'] as String?,
      metadata: (data['metadata'] as Map<String, dynamic>?) ?? {},
      createdAt: parseDate(data['created_at']),
    );
  }
}
