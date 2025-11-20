# AdMob Android Manifest Fix

## What Changed
- Added AdMob Application ID requirement to `android/app/src/main/AndroidManifest.xml`
- Updated AdMob service to use **Google's official test ad unit IDs** (safe for development)
- Simplified the widget API (removed `useTestAd` parameter)

## Quick Fix for the Error

The error you saw means Android needs your AdMob Application ID in the manifest.

### Option 1: Use Test App ID (Quick Testing)
Replace the placeholder in `android/app/src/main/AndroidManifest.xml`:

**BEFORE:**
```xml
<!-- AdMob Application ID - Replace with your real ID from https://admob.google.com -->
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-xxxxxxxxxxxxxxxx~yyyyyyyyyyyyyy"/>
```

**AFTER (with test ID):**
```xml
<!-- AdMob Application ID - Using test ID for safe development -->
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-3940256099942544~3347511713"/>
```

Then rebuild: `flutter clean && flutter pub get && flutter run`

### Option 2: Use Your Real AdMob App ID (Production)

1. Go to [AdMob Console](https://admob.google.com)
2. Find your **App ID** (format: `ca-app-pub-xxxxxxxxxxxxxxxx~yyyyyyyyyyyyyy`)
3. Replace in manifest:
```xml
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-YOUR-APP-ID~YOUR-APP-ID-NUMBER"/>
```

## Current Setup
- ✅ Using **Google's official test ad unit IDs** (won't get you banned)
- ✅ Safe for development and testing
- ✅ No need to change code when switching to real IDs (only manifest + service)

## Next Steps
1. Choose Option 1 or 2 above
2. Update the manifest file
3. Run: `flutter clean && flutter pub get && flutter run`
4. The app should now launch without the AdMob error

## Important Notes
- The test ad unit IDs (`ca-app-pub-3940256099942544/...`) are provided by Google and safe to use
- When you're ready to use real ads, just update the ad unit IDs in `lib/services/admob_service.dart` and the app ID in the manifest
