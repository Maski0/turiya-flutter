#!/bin/bash

# Find and start emulator
AVD_NAME=$(emulator -list-avds 2>&1 | grep Pixel | head -n 1)

if [ -z "$AVD_NAME" ]; then
    echo "Error: No Pixel emulator found" >&2
    exit 1
fi

echo "Starting emulator: $AVD_NAME"
emulator -avd "$AVD_NAME" -no-snapshot-load > /dev/null 2>&1 &

echo "Waiting for device..."

# Wait for emulator with manual timeout (compatible with Git Bash on Windows)
COUNTER=0
MAX_WAIT=60
until adb shell getprop sys.boot_completed 2>&1 | grep -q "1"; do
    sleep 2
    COUNTER=$((COUNTER + 2))
    if [ $COUNTER -ge $MAX_WAIT ]; then
        echo "Error: Timeout waiting for emulator to start" >&2
        exit 1
    fi
done

echo "Device ready"

# Set up ADB port forwarding for backend API (localhost:8080 → emulator)
echo "Setting up port forwarding..."
adb reverse tcp:8080 tcp:8080 > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "Error: Failed to establish port forwarding for backend (8080)" >&2
    exit 1
fi

echo "✅ Port forwarding established (emulator:8080 → localhost:8080)"
echo ""
echo "✅ Setup complete! Emulator is ready."
echo "   Backend URL: http://10.0.2.2:8080"
echo ""
echo "   To run the app: flutter run"