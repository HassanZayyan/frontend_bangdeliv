class AppRoutes {
  static const String splash = '/splash';
  static const String login = '/login';
  static const String register = '/register';
  static const String registerSuccess = '/register-success';
  static const String forgotPassword = '/forgot-password';
  static const String completePhone = '/complete-phone';
  static const String home = '/home';
  static const String driverHome = '/driver/home';
  static const String driverOrders = '/driver/orders';
  static const String driverOrderActive = '/driver/orders/:orderId/active';
  static const String driverHistory = '/driver/history';
  static const String driverHistoryDetail = '/driver/history/:orderId';
  static const String driverProfile = '/driver/profile';
  static const String driverVerificationStatus = '/driver/verification-status';
  static const String chatbot = '/chatbot';
  static const String activity = '/activity';
  static const String history = '/history';
  static const String orders = '/orders';
  static const String profile = '/profile';
  static const String editProfile = '/edit-profile';
  static const String changePassword = '/change-password';
  static const String createPassword = '/create-password';
  static const String addresses = '/addresses';
  static const String addressPicker = '/addresses/select';
  static const String addAddress = '/addresses/add';
  static const String addressLocationPicker = '/addresses/location-picker';
  static const String routeLocationPicker = '/route-location-picker';
  static const String notificationSettings = '/notification-settings';
  static const String track = '/track';
  static const String orderTrack = '/orders/:orderId/track';
  static const String shoppingAddItem = '/orders/:orderId/shopping/add-item';
  static const String shoppingMerchantMapPicker =
      '/orders/:orderId/shopping/merchant-map-picker';
  static const String chatbotShoppingMerchantPicker =
      '/chatbot/shopping/merchant-picker';
  static const String chatbotShoppingMerchantMapPicker =
      '/chatbot/shopping/merchant-map-picker';
  static const String orderChat = '/orders/:orderId/chat';
  static const String menuDetail = '/menu/:menuId';
  static const String merchantDetail = '/merchant/:merchantId';
  static const String nearbyMerchants = '/merchants/nearby';
  static const String nearbyMerchantDetail = ':merchantId';
  static const String registerDriver = '/register-driver';
  static const String privacyMapPreview = '/privacy-map-preview';

  static String menuDetailPath(String menuId) {
    return '/menu/$menuId';
  }

  static String merchantDetailPath(String merchantId) {
    return '/merchant/$merchantId';
  }

  static String addressesForOrder() {
    return '$addresses?source=order';
  }

  static String nearbyMerchantDetailPath(String merchantId) {
    return '/merchants/nearby/$merchantId';
  }

  static String shoppingAddItemPath(Object orderId) {
    return '/orders/$orderId/shopping/add-item';
  }

  static String shoppingMerchantMapPickerPath(Object orderId) {
    return '/orders/$orderId/shopping/merchant-map-picker';
  }

  static String chatbotShoppingMerchantMapPickerPath() {
    return chatbotShoppingMerchantMapPicker;
  }

  static String chatbotShoppingMerchantPickerPath() {
    return chatbotShoppingMerchantPicker;
  }

  static String driverOrderActivePath(String orderId) {
    return '/driver/orders/$orderId/active';
  }

  static String driverHistoryDetailPath(Object orderId) {
    return '/driver/history/$orderId';
  }

  static String orderChatPath(Object orderId) {
    return '/orders/$orderId/chat';
  }

  static String orderTrackPath(
    Object orderId, {
    String? focus,
    int? pickupLocationId,
  }) {
    final path = '/orders/$orderId/track';
    if (focus == null || focus.trim().isEmpty) {
      return path;
    }

    final query = Uri(
      queryParameters: {
        'focus': focus.trim(),
        if (pickupLocationId != null)
          'pickup_location_id': pickupLocationId.toString(),
      },
    ).query;

    return '$path?$query';
  }
}
