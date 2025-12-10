#!/bin/bash

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_step() { echo -e "${CYAN}🔧 $1${NC}"; }

echo ""
echo "╔════════════════════════════════════════════════════════╗"
echo "║     Build UnityFramework from Unity Export            ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

# Check if unityLibrary exists
if [ ! -d "ios/unityLibrary" ]; then
    print_error "ios/unityLibrary not found!"
    print_info "Please export from Unity first:"
    print_info "  Unity → Flutter Embed → Export project to Flutter app (iOS)"
    exit 1
fi

# Check if Unity-iPhone.xcodeproj exists
if [ ! -d "ios/unityLibrary/Unity-iPhone.xcodeproj" ]; then
    print_error "Unity-iPhone.xcodeproj not found in ios/unityLibrary!"
    print_info ""
    print_info "Your Unity export is incomplete. It should contain:"
    print_info "  - Unity-iPhone.xcodeproj (Xcode project)"
    print_info "  - Data/ (runtime data)"
    print_info "  - Libraries/ (static libraries)"  
    print_info ""
    print_warning "Possible solutions:"
    print_info "  1. Re-export from Unity using: Flutter Embed → Export (make sure export completes)"
    print_info "  2. Or just update Data folder if you have a working binary (run update_unity_build.sh)"
    exit 1
fi

print_info "Found Unity Xcode project"
print_info "Unity export: $(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" ios/unityLibrary 2>/dev/null)"
echo ""

# Get the development team from the main project
print_step "Detecting development team..."
TEAM_ID="MQNKR7K8AT"

if [ -n "$TEAM_ID" ]; then
    print_success "Found team: $TEAM_ID"
else
    print_warning "No team found in Runner project, will try without explicit team"
fi

# Build UnityFramework using xcodebuild
print_step "Building UnityFramework for device..."
echo ""

cd ios/unityLibrary

# Build for device (arm64)
if [ -n "$TEAM_ID" ]; then
    xcodebuild -project Unity-iPhone.xcodeproj \
        -scheme UnityFramework \
        -configuration Release \
        -sdk iphoneos \
        -arch arm64 \
        -derivedDataPath build \
        DEVELOPMENT_TEAM="$TEAM_ID" \
        CODE_SIGN_IDENTITY="Apple Development" \
        BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
        SKIP_INSTALL=NO \
        | grep -E "^\*\*|error:|warning:|succeeded|failed" || true
else
    xcodebuild -project Unity-iPhone.xcodeproj \
        -scheme UnityFramework \
        -configuration Release \
        -sdk iphoneos \
        -arch arm64 \
        -derivedDataPath build \
        CODE_SIGN_IDENTITY="-" \
        CODE_SIGNING_REQUIRED=NO \
        BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
        SKIP_INSTALL=NO \
        | grep -E "^\*\*|error:|warning:|succeeded|failed" || true
fi

if [ ${PIPESTATUS[0]} -ne 0 ]; then
    print_error "Build failed!"
    exit 1
fi

echo ""
print_success "UnityFramework built successfully!"
echo ""

# Find the built framework
FRAMEWORK_PATH="build/Build/Products/Release-iphoneos/UnityFramework.framework"

if [ ! -d "$FRAMEWORK_PATH" ]; then
    print_error "Built framework not found at: $FRAMEWORK_PATH"
    exit 1
fi

print_info "Built framework: $FRAMEWORK_PATH"

# Copy to pub-cache
print_step "Copying framework to pub-cache..."

UNITY_PLUGIN=$(find "$HOME/.pub-cache/hosted/pub.dev" -maxdepth 1 -name "flutter_embed_unity_2022_3_ios-*" 2>/dev/null | head -1)

if [ -z "$UNITY_PLUGIN" ]; then
    print_error "Unity iOS plugin not found in pub-cache"
    exit 1
fi

# Backup existing if it's not a symlink
if [ -e "$UNITY_PLUGIN/ios/UnityFramework.framework" ] && [ ! -L "$UNITY_PLUGIN/ios/UnityFramework.framework" ]; then
    print_step "Backing up old framework..."
    rm -rf "$UNITY_PLUGIN/ios/UnityFramework.framework.backup"
    mv "$UNITY_PLUGIN/ios/UnityFramework.framework" "$UNITY_PLUGIN/ios/UnityFramework.framework.backup"
fi

# Remove existing
rm -rf "$UNITY_PLUGIN/ios/UnityFramework.framework"

# Copy new framework
cp -R "$FRAMEWORK_PATH" "$UNITY_PLUGIN/ios/UnityFramework.framework"

print_success "Framework copied to pub-cache"

cd ../..

# Clean and rebuild
print_step "Cleaning Flutter build..."
flutter clean
flutter pub get

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
print_success "🎉 Build completed successfully!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
print_info "Next steps:"
echo "  📱 Run: flutter run"
echo ""
