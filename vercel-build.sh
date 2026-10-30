#!/bin/bash
set -e

git config --global --add safe.directory "*" || true

echo "==> Checking configuration files..."
if [ ! -f "lib/config/api_keys.dart" ]; then
  echo "==> Creating lib/config/api_keys.dart from environment variables..."
  cat << 'EOF' > lib/config/api_keys.dart
class ApiKeys {
  static const String pixabayApiKey = String.fromEnvironment('PIXABAY_API_KEY', defaultValue: '');
  static const String r2AccountId = String.fromEnvironment('R2_ACCOUNT_ID', defaultValue: '');
  static const String r2BucketName = String.fromEnvironment('R2_BUCKET_NAME', defaultValue: '');
  static const String r2AccessKeyId = String.fromEnvironment('R2_ACCESS_KEY_ID', defaultValue: '');
  static const String r2SecretAccessKey = String.fromEnvironment('R2_SECRET_ACCESS_KEY', defaultValue: '');
  static const String r2PublicBaseUrl = String.fromEnvironment('R2_PUBLIC_BASE_URL', defaultValue: '');
}
EOF
fi

echo "==> Setting up Flutter SDK..."
if [ ! -d "_flutter" ]; then
  git clone --depth 1 --branch stable https://github.com/flutter/flutter.git _flutter
fi
export PATH="$PATH:$(pwd)/_flutter/bin"

echo "==> Disabling Flutter analytics..."
flutter config --no-analytics

echo "==> Precaching Flutter web engine..."
flutter precache --web

echo "==> Building Flutter Web Release..."
flutter build web --release --base-href / \
  --dart-define=PIXABAY_API_KEY="${PIXABAY_API_KEY}" \
  --dart-define=R2_ACCOUNT_ID="${R2_ACCOUNT_ID}" \
  --dart-define=R2_BUCKET_NAME="${R2_BUCKET_NAME}" \
  --dart-define=R2_ACCESS_KEY_ID="${R2_ACCESS_KEY_ID}" \
  --dart-define=R2_SECRET_ACCESS_KEY="${R2_SECRET_ACCESS_KEY}" \
  --dart-define=R2_PUBLIC_BASE_URL="${R2_PUBLIC_BASE_URL}"

echo "==> Build complete! Output directory: build/web"
