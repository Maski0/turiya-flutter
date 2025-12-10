# Unity iOS Build Guide

## Quick Steps to Build Unity for iOS

### 1. Export from Unity Editor

- Open Unity project: `turiya-unity`
- Go to **File → Build Settings**
- Select **iOS** platform (click "Switch Platform" if needed)
- ✅ Check **"Development Build"** (CRITICAL!)
- Click **"Build"**
- Export to: `/Users/amarjeetsarma/Desktop/turiya/turiya-flutter/ios/unityLibrary`
- Wait for export to complete (2-5 minutes)

### 2. Build UnityFramework

```bash
cd /Users/amarjeetsarma/Desktop/turiya/turiya-flutter
./build_unity_framework.sh
```

### 3. Run Flutter App

```bash
flutter run
```

---

## Important Notes

- **Always check "Development Build"** in Unity - this exports the Xcode project needed to build the framework
- If build fails, make sure you have **5GB+ free disk space**
- The framework uses Team ID: `MQNKR7K8AT`
- After any Unity scene changes, repeat steps 1-3

## Troubleshooting

**"Unity-iPhone.xcodeproj not found"**
→ You forgot to check "Development Build" in Unity

**"Build failed: No space left on device"**
→ Free up disk space (delete Xcode DerivedData, Unity caches)

**"Unable to find module dependency: UnityFramework"**
→ You skipped step 2 (build_unity_framework.sh)
