#!/bin/bash

# Wireless ADB Setup Script
# Based on: https://stackoverflow.com/questions/4893953/run-install-debug-android-applications-over-wi-fi

set -e

echo "📱 Wireless ADB Setup"
echo "===================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
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

# Check if adb is installed
if ! command -v adb &> /dev/null; then
    print_error "adb not found! Please install Android SDK Platform Tools."
    exit 1
fi

# Function to get device IP
get_device_ip() {
    local device_serial=$1
    
    # Try different methods to get IP (for different Android versions)
    
    # Method 1: ip route (works on most devices)
    local ip=$(adb -s "$device_serial" shell ip route 2>/dev/null | grep -oP 'src \K[0-9.]+' | head -1)
    
    if [ -z "$ip" ]; then
        # Method 2: ifconfig wlan0 (older devices)
        ip=$(adb -s "$device_serial" shell ifconfig wlan0 2>/dev/null | grep 'inet addr:' | cut -d: -f2 | awk '{print $1}')
    fi
    
    if [ -z "$ip" ]; then
        # Method 3: ip addr show wlan0 (Android 10+)
        ip=$(adb -s "$device_serial" shell ip -f inet addr show wlan0 2>/dev/null | grep -oP 'inet \K[0-9.]+' | head -1)
    fi
    
    if [ -z "$ip" ]; then
        # Method 4: netcfg (very old devices)
        ip=$(adb -s "$device_serial" shell netcfg 2>/dev/null | grep wlan0 | awk '{print $3}' | cut -d'/' -f1)
    fi
    
    echo "$ip"
}

# Function to setup wireless debugging
setup_wireless() {
    print_info "Checking for USB-connected devices..."
    
    # Get list of USB devices
    usb_devices=$(adb devices | grep -v "List of devices" | grep "device$" | awk '{print $1}')
    
    if [ -z "$usb_devices" ]; then
        print_error "No USB devices found!"
        print_info "Please:"
        print_info "  1. Connect your Android device via USB"
        print_info "  2. Enable USB Debugging in Developer Options"
        print_info "  3. Accept the USB debugging prompt on your device"
        exit 1
    fi
    
    # Count devices
    device_count=$(echo "$usb_devices" | wc -l)
    
    if [ "$device_count" -eq 1 ]; then
        device_serial=$(echo "$usb_devices" | head -1)
        print_success "Found device: $device_serial"
    else
        print_warning "Multiple devices found:"
        echo "$usb_devices"
        echo ""
        read -p "Enter device serial: " device_serial
    fi
    
    # Enable TCP/IP mode on port 5555
    print_info "Enabling TCP/IP mode on port 5555..."
    adb -s "$device_serial" tcpip 5555
    
    if [ $? -ne 0 ]; then
        print_error "Failed to enable TCP/IP mode"
        exit 1
    fi
    
    sleep 2
    
    # Get device IP address
    print_info "Getting device IP address..."
    device_ip=$(get_device_ip "$device_serial")
    
    if [ -z "$device_ip" ]; then
        print_error "Could not detect device IP address!"
        print_info "Please manually find your device's WiFi IP address:"
        print_info "  Settings → About Phone → Status → IP Address"
        read -p "Enter device IP: " device_ip
    else
        print_success "Device IP: $device_ip"
    fi
    
    # Confirm before disconnecting USB
    print_warning "You can now disconnect the USB cable"
    read -p "Press Enter when USB is disconnected..."
    
    # Connect via WiFi
    print_info "Connecting to device via WiFi ($device_ip:5555)..."
    adb connect "$device_ip:5555"
    
    if [ $? -eq 0 ]; then
        sleep 2
        
        # Verify connection
        if adb devices | grep -q "$device_ip:5555"; then
            print_success "Successfully connected via WiFi!"
            print_info ""
            print_info "Device: $device_ip:5555"
            print_info "You can now use 'flutter run' or Android Studio wirelessly"
            print_info ""
            print_warning "SECURITY WARNING:"
            print_info "  Anyone on your network can now connect to your device!"
            print_info "  Run './disconnect_wifi_adb.sh' when done"
            
            # Save IP for later
            echo "$device_ip" > /tmp/adb_wifi_ip
            
            # Set up port forwarding for backend
            echo ""
            print_info "Setting up port forwarding (backend @ localhost:8080)..."
            sleep 1
            adb -s "$device_ip:5555" reverse tcp:8080 tcp:8080 > /dev/null 2>&1
            if [ $? -eq 0 ]; then
                print_success "Port forwarding active"
                print_info "Your device can now reach backend at localhost:8080"
            else
                print_warning "Port forwarding failed"
                print_info "Run manually: adb reverse tcp:8080 tcp:8080"
            fi
        else
            print_error "Connection failed!"
            print_info "Make sure your device and computer are on the same WiFi network"
        fi
    else
        print_error "Failed to connect via WiFi"
    fi
}

# Function to disconnect wireless debugging
disconnect_wireless() {
    print_info "Disconnecting wireless ADB..."
    
    # Check if we have saved IP
    if [ -f /tmp/adb_wifi_ip ]; then
        device_ip=$(cat /tmp/adb_wifi_ip)
        adb disconnect "$device_ip:5555"
        rm /tmp/adb_wifi_ip
    fi
    
    # Disconnect all WiFi devices
    adb disconnect
    
    print_success "Disconnected from wireless devices"
    print_info "Reconnect your device via USB if needed"
}

# Function to switch back to USB mode
switch_to_usb() {
    print_info "Switching device back to USB mode..."
    
    if [ -f /tmp/adb_wifi_ip ]; then
        device_ip=$(cat /tmp/adb_wifi_ip)
        adb -s "$device_ip:5555" usb
        print_success "Device switched back to USB mode"
        rm /tmp/adb_wifi_ip
    else
        print_warning "No wireless device found"
        print_info "If your device is connected wirelessly, find it with 'adb devices'"
        print_info "Then run: adb -s <IP>:5555 usb"
    fi
}

# Function to show status
show_status() {
    print_info "Current ADB devices:"
    adb devices -l
    echo ""
    
    if [ -f /tmp/adb_wifi_ip ]; then
        device_ip=$(cat /tmp/adb_wifi_ip)
        print_info "Saved wireless device: $device_ip:5555"
    else
        print_info "No wireless connection saved"
    fi
}

# Main script logic
case "${1:-setup}" in
    setup|connect)
        setup_wireless
        ;;
    disconnect)
        disconnect_wireless
        ;;
    usb)
        switch_to_usb
        ;;
    status)
        show_status
        ;;
    help|--help|-h)
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  setup      - Setup wireless ADB (default)"
        echo "  connect    - Same as setup"
        echo "  disconnect - Disconnect wireless ADB"
        echo "  usb        - Switch device back to USB mode"
        echo "  status     - Show current device status"
        echo "  help       - Show this help message"
        echo ""
        echo "Example workflow:"
        echo "  1. Connect device via USB"
        echo "  2. ./setup_wifi_adb.sh setup"
        echo "  3. Disconnect USB cable when prompted"
        echo "  4. Use 'flutter run' or Android Studio normally"
        echo "  5. ./disconnect_wifi_adb.sh (when done)"
        echo ""
        echo "Or use the standalone disconnect script:"
        echo "  ./disconnect_wifi_adb.sh"
        ;;
    *)
        print_error "Unknown command: $1"
        print_info "Run './setup_wifi_adb.sh help' for usage"
        exit 1
        ;;
esac

