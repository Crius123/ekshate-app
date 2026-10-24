class RoutePaths {
  RoutePaths._();

  static const String dailySale = '/';
  static const String catalog = '/catalog';
  static const String cart = '/cart';
  static const String checkout = '/checkout';
  static const String orders = '/orders';
  static const String wallet = '/wallet';
  static const String login = '/login';
  static const String profileSetup = '/profile-setup';
  static const String procurement = '/procurement';
  static const String notifications = '/notifications';
  static const String admin = '/admin';
  static const String productDetails = '/product/:id';
  static String productDetailsPath(String id) => '/product/$id';
  static const String categoryProducts = '/category/:categoryName';
  static String categoryProductsPath(String categoryName) =>
      '/category/${Uri.encodeComponent(categoryName)}';
}
