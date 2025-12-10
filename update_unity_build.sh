#!/bin/bash

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored messages
print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_step() {
    echo -e "${CYAN}🔧 $1${NC}"
}

# Function to display usage
usage() {
    echo ""
    echo "Usage: ./update_unity_build.sh [--platform ios|android|all]"
    echo ""
    echo "This script updates the Unity build after exporting from Unity Editor."
    echo ""
    echo "Options:"
    echo "  --platform ios      Update iOS Unity build only"
    echo "  --platform android  Update Android Unity build only"
    echo "  --platform all      Update both platforms (default)"
    echo "  --help, -h          Show this help message"
    echo ""
    echo "What this script does:"
    echo "  1. Links the new Unity export to the Flutter plugin cache"
    echo "  2. Clears all Xcode/Gradle build caches"
    echo "  3. Reinstalls dependencies (CocoaPods/Gradle)"
    echo "  4. Prepares the project for a clean build"
    echo ""
    exit 0
}

# Function to update iOS Unity build
update_ios_unity() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_info "📱 Updating iOS Unity Build"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Check if unityLibrary exists
    if [ ! -d "ios/unityLibrary" ]; then
        print_error "ios/unityLibrary not found!"
        print_info "Please export your Unity project to ios/unityLibrary first:"
        print_info "  Unity → Flutter Embed → Export project to Flutter app (iOS)"
        return 1
    fi
    
    # Get Unity export timestamp
    UNITY_EXPORT_TIME=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" ios/unityLibrary 2>/dev/null)
    print_info "Unity export timestamp: $UNITY_EXPORT_TIME"
    
    # Find Unity iOS plugin in pub-cache
    print_step "Finding Unity iOS plugin in pub-cache..."
    UNITY_PLUGIN=$(find "$HOME/.pub-cache/hosted/pub.dev" -maxdepth 1 -name "flutter_embed_unity_2022_3_ios-*" 2>/dev/null | head -1)
    
    if [ -z "$UNITY_PLUGIN" ]; then
        print_error "Unity iOS plugin not found in pub-cache!"
        print_info "Run 'flutter pub get' first."
        return 1
    fi
    
    print_success "Found plugin at: $UNITY_PLUGIN"
    
    # Check if old framework exists and backup if needed
    if [ -e "$UNITY_PLUGIN/ios/UnityFramework.framework" ] && [ ! -L "$UNITY_PLUGIN/ios/UnityFramework.framework" ]; then
        OLD_FRAMEWORK_TIME=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$UNITY_PLUGIN/ios/UnityFramework.framework" 2>/dev/null || echo "unknown")
        print_warning "Old framework timestamp: $OLD_FRAMEWORK_TIME"
        
        # Backup the old framework (it has the compiled binary we need)
        print_step "Backing up old framework binary..."
        if [ ! -d "$UNITY_PLUGIN/ios/UnityFramework.framework.backup" ]; then
            cp -R "$UNITY_PLUGIN/ios/UnityFramework.framework" "$UNITY_PLUGIN/ios/UnityFramework.framework.backup"
            print_success "Backup created"
        fi
    fi
    
    # Remove existing (symlink or directory)
    if [ -e "$UNITY_PLUGIN/ios/UnityFramework.framework" ]; then
        print_step "Removing old Unity framework from pub-cache..."
        rm -rf "$UNITY_PLUGIN/ios/UnityFramework.framework"
        print_success "Old framework removed"
    fi
    
    # Check if we have a backup with the compiled binary
    if [ -f "$UNITY_PLUGIN/ios/UnityFramework.framework.backup/UnityFramework" ]; then
        print_step "Restoring framework structure with new Data..."
        
        # Copy the backup framework structure
        cp -R "$UNITY_PLUGIN/ios/UnityFramework.framework.backup" "$UNITY_PLUGIN/ios/UnityFramework.framework"
        
        # Replace Data folder with new export
        rm -rf "$UNITY_PLUGIN/ios/UnityFramework.framework/Data"
        cp -R "ios/unityLibrary/Data" "$UNITY_PLUGIN/ios/UnityFramework.framework/Data"
        
        # Update Libraries folder if it exists
        if [ -d "ios/unityLibrary/Libraries" ]; then
            rm -rf "$UNITY_PLUGIN/ios/UnityFramework.framework/Libraries" 2>/dev/null
            cp -R "ios/unityLibrary/Libraries" "$UNITY_PLUGIN/ios/UnityFramework.framework/Libraries"
            print_success "Updated Data and Libraries folders"
        fi
        
        NEW_FRAMEWORK_TIME=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$UNITY_PLUGIN/ios/UnityFramework.framework/Data" 2>/dev/null)
        print_success "Framework updated with new Data (timestamp: $NEW_FRAMEWORK_TIME)"
    else
        print_error "No compiled UnityFramework binary found!"
        print_warning "The Unity export in ios/unityLibrary doesn't have a compiled binary."
        echo ""
        print_info "You have two options:"
        echo ""
        print_info "Option 1: Build the framework from Unity export (if you have Unity-iPhone.xcodeproj):"
        echo "    ./build_unity_framework.sh"
        echo ""
        print_info "Option 2: If you only changed Unity scenes/assets (not C# code):"
        echo "    - Keep using the old framework binary"
        echo "    - Just update the Data folder"
        echo "    - Run: ./update_unity_build.sh --platform ios"
        echo ""
        return 1
    fi
    
    # Clear Xcode Derived Data
    print_step "Clearing Xcode Derived Data..."
    if [ -d "$HOME/Library/Developer/Xcode/DerivedData" ]; then
        rm -rf "$HOME/Library/Developer/Xcode/DerivedData/Runner-"*
        print_success "Xcode Derived Data cleared"
    fi
    
    # Clear CocoaPods cache
    print_step "Clearing CocoaPods cache..."
    if [ -d "$HOME/Library/Caches/CocoaPods" ]; then
        rm -rf "$HOME/Library/Caches/CocoaPods"
        print_success "CocoaPods cache cleared"
    fi
    
    # Clear iOS build folder
    print_step "Clearing iOS build folder..."
    if [ -d "build/ios" ]; then
        rm -rf build/ios
        print_success "iOS build folder cleared"
    fi
    
    # Deintegrate and reinstall CocoaPods
    if [ -d "ios" ]; then
        cd ios
        
        if command -v pod &> /dev/null; then
            print_step "Deintegrating CocoaPods..."
            pod deintegrate &> /dev/null || print_warning "Pod deintegrate skipped (not needed)"
            
            print_step "Reinstalling CocoaPods (this may take a minute)..."
            if pod install --repo-update; then
                print_success "CocoaPods reinstalled successfully"
            else
                print_error "CocoaPods installation failed"
                cd ..
                return 1
            fi
        else
            print_error "CocoaPods not found. Please install it first: sudo gem install cocoapods"
            cd ..
            return 1
        fi
        
        cd ..
    fi
    
    echo ""
    print_success "iOS Unity build update completed!"
    echo ""
    
    return 0
}

# Function to update Android Unity build
update_android_unity() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_info "🤖 Updating Android Unity Build"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Check if unityLibrary exists
    if [ ! -d "android/unityLibrary" ]; then
        print_error "android/unityLibrary not found!"
        print_info "Please export your Unity project to android/unityLibrary first:"
        print_info "  Unity → Flutter Embed → Export project to Flutter app (Android)"
        return 1
    fi
    
    # Get Unity export timestamp
    UNITY_EXPORT_TIME=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" android/unityLibrary 2>/dev/null || stat -c "%y" android/unityLibrary 2>/dev/null)
    print_info "Unity export timestamp: $UNITY_EXPORT_TIME"
    
    # Find Unity Android plugin in pub-cache
    print_step "Finding Unity Android plugin in pub-cache..."
    UNITY_PLUGIN=$(find "$HOME/.pub-cache/hosted/pub.dev" -maxdepth 1 -name "flutter_embed_unity_2022_3_android-*" 2>/dev/null | head -1)
    
    if [ -z "$UNITY_PLUGIN" ]; then
        print_error "Unity Android plugin not found in pub-cache!"
        print_info "Run 'flutter pub get' first."
        return 1
    fi
    
    print_success "Found plugin at: $UNITY_PLUGIN"
    
    # Clear Gradle caches
    print_step "Clearing Gradle cache..."
    if [ -d "$HOME/.gradle/caches" ]; then
        rm -rf "$HOME/.gradle/caches"
        print_success "Gradle cache cleared"
    fi
    
    # Clear Android build folders
    print_step "Clearing Android build folders..."
    if [ -d "build/android" ]; then
        rm -rf build/android
        print_success "Android build folder cleared"
    fi
    
    if [ -d "android/app/build" ]; then
        rm -rf android/app/build
        print_success "Android app build folder cleared"
    fi
    
    if [ -d "android/.gradle" ]; then
        rm -rf android/.gradle
        print_success "Android .gradle folder cleared"
    fi
    
    # Run Gradle clean
    if [ -d "android" ]; then
        cd android
        
        if [ -f "gradlew" ]; then
            print_step "Running Gradle clean..."
            if ./gradlew clean &> /dev/null; then
                print_success "Gradle clean completed"
            else
                print_warning "Gradle clean had issues (this might be okay)"
            fi
        else
            print_warning "Gradle wrapper not found"
        fi
        
        cd ..
    fi
    
    echo ""
    print_success "Android Unity build update completed!"
    echo ""
    
    return 0
}

# Main script
main() {
    echo ""
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║         Unity Build Update Script                     ║"
    echo "║  Updates Unity export after building from Unity Editor ║"
    echo "╚════════════════════════════════════════════════════════╝"
    
    # Get script directory (project root)
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    cd "$SCRIPT_DIR"
    
    # Parse arguments
    PLATFORM="all"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --platform)
                PLATFORM="$2"
                shift 2
                ;;
            --help|-h)
                usage
                ;;
            *)
                print_error "Unknown option: $1"
                usage
                ;;
        esac
    done
    
    # Validate platform
    if [[ ! "$PLATFORM" =~ ^(ios|android|all)$ ]]; then
        print_error "Invalid platform: $PLATFORM"
        print_info "Valid options: ios, android, all"
        exit 1
    fi
    
    # Track success
    SUCCESS=true
    
    # Update iOS if requested
    if [[ "$PLATFORM" == "ios" || "$PLATFORM" == "all" ]]; then
        if ! update_ios_unity; then
            SUCCESS=false
        fi
    fi
    
    # Update Android if requested
    if [[ "$PLATFORM" == "android" || "$PLATFORM" == "all" ]]; then
        if ! update_android_unity; then
            SUCCESS=false
        fi
    fi
    
    # Clean Flutter build
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_info "🔵 Flutter Clean & Pub Get"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    if command -v flutter &> /dev/null; then
        print_step "Running flutter clean..."
        flutter clean
        print_success "Flutter clean completed"
        
        print_step "Running flutter pub get..."
        flutter pub get
        print_success "Flutter pub get completed"
    else
        print_error "Flutter not found in PATH"
        SUCCESS=false
    fi
    
    # Final message
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if [ "$SUCCESS" = true ]; then
        print_success "🎉 Unity build update completed successfully!"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        print_info "Next steps:"
        if [[ "$PLATFORM" == "ios" || "$PLATFORM" == "all" ]]; then
            echo "  📱 iOS: flutter run -d <ios-device>"
        fi
        if [[ "$PLATFORM" == "android" || "$PLATFORM" == "all" ]]; then
            echo "  🤖 Android: flutter run -d <android-device>"
        fi
        echo ""
        exit 0
    else
        print_error "Update completed with errors. Please check the output above."
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        exit 1
    fi
}

# Run main function
main "$@"
