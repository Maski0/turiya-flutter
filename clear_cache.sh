#!/bin/bash

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# Function to clear iOS cache
clear_ios_cache() {
    print_info "Clearing iOS caches..."
    
    # Clear Xcode Derived Data
    if [ -d "$HOME/Library/Developer/Xcode/DerivedData" ]; then
        print_info "Clearing Xcode Derived Data..."
        rm -rf "$HOME/Library/Developer/Xcode/DerivedData/Runner-"*
        print_success "Xcode Derived Data cleared"
    else
        print_warning "Xcode Derived Data directory not found"
    fi
    
    # Clear CocoaPods cache
    if [ -d "$HOME/Library/Caches/CocoaPods" ]; then
        print_info "Clearing CocoaPods cache..."
        rm -rf "$HOME/Library/Caches/CocoaPods"
        print_success "CocoaPods cache cleared"
    else
        print_warning "CocoaPods cache directory not found"
    fi
    
    # Clear iOS build folder
    if [ -d "build/ios" ]; then
        print_info "Clearing iOS build folder..."
        rm -rf build/ios
        print_success "iOS build folder cleared"
    fi
    
    # CRITICAL: Update Unity framework in pub-cache
    if [ -d "ios/unityLibrary" ]; then
        UNITY_PLUGIN_PATH=$(find "$HOME/.pub-cache/hosted/pub.dev" -maxdepth 1 -name "flutter_embed_unity_2022_3_ios-*" 2>/dev/null | head -1)
        
        if [ -n "$UNITY_PLUGIN_PATH" ] && [ -d "$UNITY_PLUGIN_PATH/ios" ]; then
            print_info "Updating Unity framework in pub-cache..."
            
            # Remove old framework
            rm -rf "$UNITY_PLUGIN_PATH/ios/UnityFramework.framework" 2>/dev/null
            
            # Create symlink to local unityLibrary
            ABSOLUTE_UNITY_PATH="$(cd "$(dirname "ios/unityLibrary")" && pwd)/$(basename "ios/unityLibrary")"
            ln -s "$ABSOLUTE_UNITY_PATH" "$UNITY_PLUGIN_PATH/ios/UnityFramework.framework"
            
            print_success "Unity framework updated in pub-cache (symlinked to local export)"
        else
            print_warning "Unity iOS plugin not found in pub-cache"
        fi
    else
        print_warning "ios/unityLibrary folder not found"
    fi
    
    # Deintegrate and reinstall pods
    if [ -d "ios" ]; then
        print_info "Deintegrating CocoaPods..."
        cd ios
        
        if command -v pod &> /dev/null; then
            pod deintegrate &> /dev/null || print_warning "Pod deintegrate failed or not needed"
            
            print_info "Reinstalling CocoaPods..."
            pod install --repo-update
            
            cd ..
            print_success "CocoaPods reinstalled successfully"
        else
            print_error "CocoaPods not found. Please install it first."
            cd ..
        fi
    else
        print_warning "iOS folder not found"
    fi
}

# Function to clear Android cache
clear_android_cache() {
    print_info "Clearing Android caches..."
    
    # Clear Gradle cache
    if [ -d "$HOME/.gradle/caches" ]; then
        print_info "Clearing Gradle cache..."
        rm -rf "$HOME/.gradle/caches"
        print_success "Gradle cache cleared"
    else
        print_warning "Gradle cache directory not found"
    fi
    
    # Clear Android build folder
    if [ -d "build/android" ]; then
        print_info "Clearing Android build folder..."
        rm -rf build/android
        print_success "Android build folder cleared"
    fi
    
    # Clear Android app build
    if [ -d "android/app/build" ]; then
        print_info "Clearing Android app build folder..."
        rm -rf android/app/build
        print_success "Android app build folder cleared"
    fi
    
    # Clean Gradle build
    if [ -d "android" ]; then
        print_info "Running Gradle clean..."
        cd android
        
        if [ -f "gradlew" ]; then
            ./gradlew clean &> /dev/null || print_warning "Gradle clean failed"
            print_success "Gradle clean completed"
        else
            print_warning "Gradle wrapper not found"
        fi
        
        cd ..
    else
        print_warning "Android folder not found"
    fi
}

# Function to clear Flutter cache
clear_flutter_cache() {
    print_info "Clearing Flutter caches..."
    
    # Flutter clean
    if command -v flutter &> /dev/null; then
        flutter clean
        print_success "Flutter clean completed"
        
        # Clear Flutter pub cache (optional - uncomment if needed)
        # flutter pub cache clean -f
        
        # Restore dependencies
        print_info "Getting Flutter dependencies..."
        flutter pub get
        print_success "Flutter dependencies restored"
    else
        print_error "Flutter not found. Please install Flutter first."
    fi
}

# Main script logic
main() {
    echo ""
    print_info "🧹 Cache Clearing Script"
    echo ""
    
    # Get script directory (project root)
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    cd "$SCRIPT_DIR"
    
    # Parse arguments
    CLEAR_IOS=false
    CLEAR_ANDROID=false
    
    if [ $# -eq 0 ]; then
        # No arguments - clear both
        CLEAR_IOS=true
        CLEAR_ANDROID=true
        print_info "No platform specified. Clearing both iOS and Android caches..."
    else
        # Parse arguments
        for arg in "$@"; do
            case $arg in
                --ios)
                    CLEAR_IOS=true
                    ;;
                --android)
                    CLEAR_ANDROID=true
                    ;;
                --help|-h)
                    echo "Usage: ./clear_cache.sh [--ios] [--android]"
                    echo ""
                    echo "Options:"
                    echo "  --ios       Clear iOS caches only"
                    echo "  --android   Clear Android caches only"
                    echo "  (no args)   Clear both iOS and Android caches"
                    echo ""
                    exit 0
                    ;;
                *)
                    print_error "Unknown option: $arg"
                    echo "Use --help for usage information"
                    exit 1
                    ;;
            esac
        done
    fi
    
    echo ""
    
    # Clear iOS cache if requested
    if [ "$CLEAR_IOS" = true ]; then
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        print_info "📱 iOS Cache Clearing"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        clear_ios_cache
        echo ""
    fi
    
    # Clear Android cache if requested
    if [ "$CLEAR_ANDROID" = true ]; then
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        print_info "🤖 Android Cache Clearing"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        clear_android_cache
        echo ""
    fi
    
    # Clear Flutter cache (always)
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_info "🔵 Flutter Cache Clearing"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    clear_flutter_cache
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_success "🎉 Cache clearing completed!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    print_info "You can now build your app:"
    if [ "$CLEAR_IOS" = true ]; then
        echo "  iOS: flutter run"
    fi
    if [ "$CLEAR_ANDROID" = true ]; then
        echo "  Android: flutter run"
    fi
    echo ""
}

# Run main function
main "$@"
