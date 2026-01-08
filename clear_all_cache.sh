#!/bin/bash

# Clear All Flutter/iOS/Android Build Cache
# Run this script when you encounter build issues or timeout errors

echo "🧹 Clearing all build cache..."

# Navigate to project root
cd "$(dirname "$0")"

# Close Xcode if running
echo "🔒 Closing Xcode..."
osascript -e 'quit app "Xcode"' 2>/dev/null || true
# Wait a moment for Xcode to fully close
sleep 2

echo "📦 Running flutter clean..."
flutter clean

echo "🗑️ Removing Xcode DerivedData..."
rm -rf ~/Library/Developer/Xcode/DerivedData

echo "🗑️ Removing iOS Pods..."
rm -rf ios/Pods
rm -rf ios/Podfile.lock
rm -rf ios/.symlinks

echo "🗑️ Removing Flutter build artifacts..."
rm -rf .dart_tool
rm -rf build
rm -rf ios/Flutter/Flutter.framework
rm -rf ios/Flutter/Flutter.podspec

echo "🗑️ Removing Android build artifacts..."
rm -rf android/.gradle
rm -rf android/app/build

echo "📥 Getting Flutter dependencies..."
flutter pub get

echo "📦 Installing CocoaPods dependencies..."
cd ios && pod install --repo-update && cd ..

echo "✅ All cache cleared successfully!"
echo ""
echo "You can now run: flutter run"
