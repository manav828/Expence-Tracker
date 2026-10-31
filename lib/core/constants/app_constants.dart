/// Application-wide constants for preferences, keys, and routes.
class AppConstants {
  AppConstants._();

  // --- SharedPreferences Keys ---
  static const String keyPendingInviteCode = 'pending_invite_code';
  static const String keyOnboardingCompleted = 'onboarding_completed';
  static const String keyStorageMode = 'storage_mode';
  static const String keyGoogleSheetsEnabled = 'gsheet_enabled';
  static const String keyGoogleSheetsUrl = 'gsheet_url';
  static const String keyGoogleSheetsSheetName = 'gsheet_sheet_name';
  static const String keyCustomCategoryOrder = 'custom_category_order';
  static const String keyCustomPaymentMethodOrder = 'custom_payment_method_order';
  static const String keyBudgetSafeguardsDismissedPrefix = 'budget_safeguards_dismissed_';

  // --- Route Names ---
  static const String routeLogin = '/login';
  static const String routeRegister = '/register';
  static const String routeOnboarding = '/onboarding';
  static const String routeMain = '/main';

  // --- UI Layout & Animation ---
  static const double defaultBorderRadius = 20.0;
  static const double cardBorderRadius = 24.0;
  static const double bottomNavHeight = 84.0;
  static const Duration defaultAnimationDuration = Duration(milliseconds: 300);
}
