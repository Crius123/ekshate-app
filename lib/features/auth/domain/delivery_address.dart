/// Structured Delivery Address for Bangladeshi bulk drop-offs
class DeliveryAddress {
  final String addressLine;
  final String area;
  final String city;

  const DeliveryAddress({
    required this.addressLine,
    required this.area,
    required this.city,
  });

  /// Formatted single-string address matching Firestore 1-500 char requirement
  String get formattedAddress => '$addressLine, $area, $city';

  /// Parses a comma-separated address into its structured components
  factory DeliveryAddress.parse(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const DeliveryAddress(
        addressLine: '',
        area: '',
        city: 'Dhaka',
      );
    }

    final parts = raw.split(',').map((p) => p.trim()).toList();
    if (parts.length >= 3) {
      final city = parts.last;
      final area = parts[parts.length - 2];
      final line = parts.sublist(0, parts.length - 2).join(', ');
      return DeliveryAddress(addressLine: line, area: area, city: city);
    } else if (parts.length == 2) {
      return DeliveryAddress(addressLine: parts[0], area: parts[1], city: 'Dhaka');
    } else {
      return DeliveryAddress(addressLine: parts[0], area: '', city: 'Dhaka');
    }
  }

  DeliveryAddress copyWith({
    String? addressLine,
    String? area,
    String? city,
  }) {
    return DeliveryAddress(
      addressLine: addressLine ?? this.addressLine,
      area: area ?? this.area,
      city: city ?? this.city,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeliveryAddress &&
          runtimeType == other.runtimeType &&
          addressLine == other.addressLine &&
          area == other.area &&
          city == other.city;

  @override
  int get hashCode => Object.hash(addressLine, area, city);

  @override
  String toString() => formattedAddress;
}
