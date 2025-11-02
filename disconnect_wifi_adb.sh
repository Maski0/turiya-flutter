#!/bin/bash

# Disconnect Wireless ADB Script
# Quick script to safely disconnect from wireless debugging

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo "ℹ️  $1"
}

echo "📱 Disconnecting Wireless ADB"
echo "=============================="
echo ""

# Check if adb is installed
if ! command -v adb &> /dev/null; then
    print_error "adb not found! Please install Android SDK Platform Tools."
    exit 1
fi

# Get all wireless devices (IP:port format)
wireless_devices=$(adb devices | grep ":" | awk '{print $1}')

if [ -z "$wireless_devices" ]; then
    print_warning "No wireless devices currently connected"
    print_info "Current devices:"
    adb devices
    exit 0
fi

print_info "Found wireless devices:"
echo "$wireless_devices"
echo ""

# Disconnect all wireless devices
for device in $wireless_devices; do
    print_info "Disconnecting from $device..."
    adb disconnect "$device"
done

# Clean up saved IP if exists
if [ -f /tmp/adb_wifi_ip ]; then
    rm /tmp/adb_wifi_ip
    print_info "Cleaned up saved wireless connection"
fi

echo ""
print_success "All wireless devices disconnected!"
print_info "You can now reconnect your device via USB if needed"
print_info ""
print_info "To check remaining devices, run: adb devices"

