#!/bin/bash
set -e

git config --global --add safe.directory "*" || true

echo "==> Configuring environment and API keys..."
cat << EOF > lib/config/api_keys.dart
class ApiKeys {
  static const String pixabayApiKey = '${PIXABAY_API_KEY:-}';
  static const String r2AccountId = '${R2_ACCOUNT_ID:-}';
  static const String r2BucketName = '${R2_BUCKET_NAME:-}';
  static const String r2AccessKeyId = '${R2_ACCESS_KEY_ID:-}';
  static const String r2SecretAccessKey = '${R2_SECRET_ACCESS_KEY:-}';
  static const String r2PublicBaseUrl = '${R2_PUBLIC_BASE_URL:-}';
}
EOF

echo "==> Setting up Flutter SDK..."
if [ ! -d "_flutter" ]; then
  git clone --depth 1 --branch stable https://github.com/flutter/flutter.git _flutter
fi
export PATH="$PATH:$(pwd)/_flutter/bin"

echo "==> Configuring Flutter settings..."
flutter config --no-analytics

# Limit Dart VM memory to fit within Vercel container RAM limits
export DART_VM_OPTIONS="--old_gen_heap_size=1536"

echo "==> Building Flutter Web Release (low memory footprint)..."
flutter build web --release \
  --base-href / \
  --no-tree-shake-icons \
  -O1 \
  --no-source-maps

echo "==> Build complete! Output in build/web"
