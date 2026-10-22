class MasterProduct {
  final String id;
  final String title;
  final String description;
  final String category;
  final String unit;
  final String thumbnailUrl;
  final List<String> mediaUrls;
  final bool isActive;

  const MasterProduct({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.unit,
    required this.thumbnailUrl,
    this.mediaUrls = const [],
    this.isActive = true,
  });
}
