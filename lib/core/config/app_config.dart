/// Centralized Environment and Application Configuration.
///
/// Values can be supplied at compile time via `--dart-define`:
/// ```bash
/// flutter run --dart-define=SUPABASE_URL=https://... --dart-define=SUPABASE_ANON_KEY=...
/// ```
/// When running in local development or CI without `--dart-define`, default fallback
/// credentials are used.
class AppConfig {
  AppConfig._();

  // --- App Metadata ---
  static const String appName = 'ExpenCircle';
  static const String appVersion = '1.0.3';
  static const int appBuildNumber = 4;

  // --- Supabase Backend ---
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://kqchjyfnvzfcxvhaonqz.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_r7uEuebZL7Ed74YQzWlTqg_VnmFZ6It',
  );

  // --- Google OAuth Client IDs ---
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '399080992633-83vkmq76bgerotmks2ol10bniofcjq4t.apps.googleusercontent.com',
  );

  static const String googleAndroidClientId = String.fromEnvironment(
    'GOOGLE_ANDROID_CLIENT_ID',
    defaultValue: '399080992633-10o8it0lqlo4dcj4hat30ndu9g3oqjm9.apps.googleusercontent.com',
  );

  static const String googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
    defaultValue: '399080992633-l5k7r4ihs15tgs41c41hktcv8uip9jer.apps.googleusercontent.com',
  );

  // --- Pixabay Cover Photos ---
  static const String pixabayApiKey = String.fromEnvironment(
    'PIXABAY_API_KEY',
    defaultValue: '54231264-d3ff3246617b74558e914701c',
  );

  // --- Cloudflare R2 Storage (Receipts & Banners) ---
  static const String r2AccountId = String.fromEnvironment(
    'R2_ACCOUNT_ID',
    defaultValue: 'e8acbf2339145c4be33e745c659773a1',
  );

  static const String r2BucketName = String.fromEnvironment(
    'R2_BUCKET_NAME',
    defaultValue: 'expencircle-storage',
  );

  static const String r2AccessKeyId = String.fromEnvironment(
    'R2_ACCESS_KEY_ID',
    defaultValue: '0a858b98473475974aa638978a326d68',
  );

  static const String r2SecretAccessKey = String.fromEnvironment(
    'R2_SECRET_ACCESS_KEY',
    defaultValue: '4c7404639cac7ef4a153d7cc4326c689d29d5c50e97f2d6c8ded76044abdec5f',
  );

  static const String r2PublicBaseUrl = String.fromEnvironment(
    'R2_PUBLIC_BASE_URL',
    defaultValue: 'https://pub-5931ad4398be42b6a8a7426e57c49b6b.r2.dev',
  );

  // --- Feature Flags & Timeouts ---
  static const int apiTimeoutSeconds = 10;
  static const int imageSearchTimeoutSeconds = 5;
  static const int defaultPageSize = 20;

  /// Returns true if Pixabay API key is configured and not placeholder.
  static bool get hasPixabayConfigured =>
      pixabayApiKey.isNotEmpty &&
      pixabayApiKey != 'YOUR_PIXABAY_API_KEY_HERE';

  /// Returns true if Cloudflare R2 credentials are configured.
  static bool get hasR2Configured =>
      r2AccountId.isNotEmpty &&
      r2BucketName.isNotEmpty &&
      r2AccessKeyId.isNotEmpty &&
      r2SecretAccessKey.isNotEmpty;
}
