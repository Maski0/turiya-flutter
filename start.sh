#!/bin/bash

echo "=========================================="
echo "  Turiya Flutter - Emulator Setup"
echo "=========================================="
echo ""

# Find emulator
AVD_NAME=$(emulator -list-avds 2>&1 | grep Pixel | head -n 1)

if [ -z "$AVD_NAME" ]; then
    echo "❌ Error: No Pixel emulator found"
    echo ""
    echo "Please create an emulator in Android Studio first."
    exit 1
fi

# Check if emulator is already running
if adb devices | grep -q "emulator"; then
    echo "✅ Emulator already running!"
    echo ""
else
    echo "📱 Found emulator: $AVD_NAME"
    echo ""
    echo "Starting emulator (this will open in a new window)..."
    
    # Start emulator - it will open in its own window
    start emulator -avd "$AVD_NAME" -no-snapshot-load
    
    echo ""
    echo "⏳ Waiting for emulator to boot..."
    echo "   (This usually takes 30-60 seconds)"
    echo ""
    
    # Wait for emulator to show up in adb
    WAIT=0
    MAX_WAIT=120
    while ! adb devices | grep -q "emulator"; do
        echo -n "."
        sleep 2
        WAIT=$((WAIT + 2))
        if [ $WAIT -ge $MAX_WAIT ]; then
            echo ""
            echo ""
            echo "⚠️  Emulator is taking longer than expected."
            echo ""
            echo "Options:"
            echo "  1. Wait for the emulator window to fully boot"
            echo "  2. Then run this script again"
            echo "  3. Or manually run: flutter run"
            echo ""
            exit 1
        fi
    done
    
    echo ""
    echo ""
    echo "✅ Emulator detected!"
    echo ""
    echo "⏳ Waiting for Android to finish booting..."
    
    # Wait for boot to complete
    WAIT=0
    MAX_WAIT=180
    while ! adb shell getprop sys.boot_completed 2>&1 | grep -q "1"; do
        sleep 3
        WAIT=$((WAIT + 3))
        if [ $WAIT -ge $MAX_WAIT ]; then
            echo ""
            echo "⚠️  Boot is taking longer than expected, but you can try running the app anyway."
            break
        fi
    done
fi

echo ""
echo "✅ Emulator is ready!"
echo ""

# Set up port forwarding
echo "🔗 Setting up port forwarding..."
sleep 2

adb reverse tcp:8080 tcp:8080 > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "⚠️  Port forwarding failed, retrying..."
    sleep 3
    adb reverse tcp:8080 tcp:8080 > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "❌ Port forwarding failed"
        echo "   You may need to run 'adb reverse tcp:8080 tcp:8080' manually"
    fi
fi

echo ""
echo "=========================================="
echo "  ✅ Setup Complete!"
echo "=========================================="
echo ""
echo "Backend URL: http://10.0.2.2:8080"
echo ""
echo "To run the app:"
echo "  flutter run"
echo ""
echo "Make sure your backend is running on localhost:8080"
echo ""
