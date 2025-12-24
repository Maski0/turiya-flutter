#!/bin/bash

echo "🧹 Cleaning Unity and iOS cache..."

# 1. Clean Flutter
echo "📦 Cleaning Flutter build..."
flutter clean

# 2. Remove iOS build artifacts
echo "🍎 Removing iOS build artifacts..."
rm -rf ios/build/
rm -rf ios/.symlinks/
rm -rf ios/Flutter/Flutter.framework
rm -rf ios/Flutter/App.framework
rm -rf ios/Flutter/engine/
rm -rf ios/Pods/
rm -rf ios/.dart_tool/
rm -rf ios/Runner.xcworkspace/xcuserdata/
rm -rf ios/Runner.xcodeproj/xcuserdata/
rm -rf ios/Runner.xcodeproj/project.xcworkspace/xcuserdata/

# 3. Remove Unity Library build artifacts  
echo "🎮 Removing Unity iOS library..."
rm -rf ios/unityLibrary/
rm -rf ios/UnityFramework.xcodeproj/

# 4. Clean DerivedData (Xcode cache)
echo "🗑️  Cleaning Xcode DerivedData..."
rm -rf ~/Library/Developer/Xcode/DerivedData/

# 5. Remove Flutter/Unity integration cache
echo "🔗 Removing Flutter-Unity cache..."
rm -rf .dart_tool/
rm -rf build/

# 6. Clean CocoaPods cache
echo "☕ Cleaning CocoaPods cache..."
cd ios
rm -rf Podfile.lock
pod cache clean --all 2>/dev/null || true
cd ..

echo ""
echo "✅ Clean complete!"
echo ""
echo "📋 Next steps:"
echo "1. Re-export Unity project to iOS (if you changed Unity scenes)"
echo "2. Run: flutter pub get"
echo "3. Run: cd ios && pod install && cd .."
echo "4. Build: flutter run"
