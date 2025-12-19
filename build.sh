#!/bin/bash
# Netlify build script for Flutter web

set -e  # Exit on any error

echo "=== Flutter Web Build Script ==="

# Install Flutter
echo "📦 Installing Flutter ${FLUTTER_VERSION}..."
git clone https://github.com/flutter/flutter.git --depth 1 --branch stable flutter
export PATH="$PATH:$(pwd)/flutter/bin"

# Verify Flutter installation
echo "✅ Flutter version:"
flutter --version

# Enable web support
echo "🌐 Enabling web support..."
flutter config --enable-web

# Get dependencies
echo "📚 Getting dependencies..."
flutter pub get

# Build for web with Supabase credentials
echo "🔨 Building web app..."
flutter build web --release \
  --dart-define=SUPABASE_URL="${SUPABASE_URL}" \
  --dart-define=SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY}" \
  --dart-define=SUPABASE_EMAIL_REDIRECT="${SUPABASE_EMAIL_REDIRECT:-}" \
  --dart-define=FEED_LINK_BASE="${FEED_LINK_BASE:-}"

echo "✅ Build complete! Output in build/web/"
ls -la build/web/

