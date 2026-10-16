class AppConfig {
  static const String appName = 'HomeConnect';
  static const String appVersion = '2.1.0';
  
  // URLs (pour future intégration API)
  static const String baseUrl = 'https://api.homeconnect.bj';
  
  // Paramètres métier
  static const double commissionRate = 0.05; // 5%
  static const double premiumCommissionRate = 0.03; // 3% pour Premium+
  static const int premiumPrice = 25000; // FCFA/mois
  
  // Limites
  static const int maxImagesPerProperty = 10;
  static const int maxFavorites = 50;
  
  // Notifications
  static const String notificationChannelId = 'immo_benin_channel';
  static const String notificationChannelName = 'HomeConnect';
}