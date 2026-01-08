#!/bin/bash

echo "🧹 Clearing all build cache..."

# Close Xcode gracefully
echo "🔒 Closing Xcode..."
osascript -e 'quit app "Xcode"' || true
sleep 2 # Give Xcode a moment to close

# Flutter clean
echo "📦 Running flutter clean..."
flutter clean

# Remove Xcode DerivedData
echo "🗑️ Removing Xcode DerivedData..."
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# Remove iOS Pods and Podfile.lock
echo "🗑️ Removing iOS Pods..."
rm -rf ios/Pods
rm -f ios/Podfile.lock

# Remove Flutter build artifacts
echo "🗑️ Removing Flutter build artifacts..."
rm -rf .dart_tool
rm -rf build

# Remove Android gradle cache
echo "🗑️ Removing Android build artifacts..."
rm -rf android/.gradle
rm -rf android/build

# Get Flutter dependencies
echo "📥 Getting Flutter dependencies..."
flutter pub get

# Install CocoaPods dependencies
echo "📦 Installing CocoaPods dependencies..."
(cd ios && pod install --repo-update)

echo "✅ All cache cleared successfully!"
echo ""
echo "You can now run: flutter run"
