# AdMob Setup Guide

## Overview
The app now includes AdMob banner ads on the Statistics page. Ads only display on **Android and iOS** devices. Desktop platforms (Windows, Linux, macOS) will not show ads.

## Implementation Details

### Files Added/Modified:
1. **`lib/services/admob_service.dart`** - AdMob service with platform detection
2. **`lib/widgets/admob_banner_widget.dart`** - Reusable banner widget
3. **`lib/main.dart`** - Initialize AdMob on app startup
4. **`lib/thong_ke.dart`** - Add banner to Statistics page
5. **`pubspec.yaml`** - Added `google_mobile_ads` dependency

### Features:
- ✅ Platform detection (only shows ads on mobile)
- ✅ Test ads enabled by default for safe development
- ✅ Graceful fallback on unsupported platforms
- ✅ Automatic ad disposal to prevent memory leaks

---

## Getting Your AdMob IDs

### 1. Create AdMob Account
1. Go to [Google AdMob](https://admob.google.com)
2. Sign in with your Google account
3. Accept the terms and set up your account

### 2. Create an App
1. In AdMob, click **Apps** → **Add App**
2. Select your platform (Android first, then iOS separately)
3. Fill in app details (name, category, etc.)
4. Get your **App ID**

### 3. Create Ad Units
1. Click **Ad units** → **Create new ad unit**
2. Choose **Banner** as ad format
3. Name it (e.g., "Statistics Page Banner")
4. You'll get an **Ad Unit ID** (format: `ca-app-pub-xxxxxxxxxxxxxxxx/yyyyyyyyyyyyy`)

### 4. Configure Android
In `android/app/AndroidManifest.xml`, add your AdMob App ID:
```xml
<manifest ...>
    <application>
        <!-- Add this inside <application> tag -->
        <meta-data
            android:name="com.google.android.gms.ads.APPLICATION_ID"
            android:value="ca-app-pub-xxxxxxxxxxxxxxxx~zzzzzzzzzz"/>
    </application>
</manifest>
```

### 5. Configure iOS
In `ios/Runner/Info.plist`, add your AdMob App ID:
```xml
<dict>
    <!-- Add this -->
    <key>GADApplicationIdentifier</key>
    <string>ca-app-pub-xxxxxxxxxxxxxxxx~zzzzzzzzzz</string>
</dict>
```

---

## Using Test Ads vs Live Ads

### Test Ads (Current Setup - Safe)
```dart
AdMobBannerWidget(useTestAd: true)  // Test ad unit ID
```
✅ Safe for development
✅ Uses Google's official test ad unit ID
✅ Won't get your account suspended

### Live Ads (Production)
In `lib/widgets/admob_banner_widget.dart`, change:
```dart
const AdMobBannerWidget(useTestAd: true)
```
to:
```dart
const AdMobBannerWidget(useTestAd: false)
```

And update `lib/services/admob_service.dart` with your real ad unit IDs:
```dart
static const String _bannerAdUnitIdAndroid = 'ca-app-pub-YOUR-REAL-ID/YOUR-AD-UNIT-ID';
static const String _bannerAdUnitIdIOS = 'ca-app-pub-YOUR-REAL-ID/YOUR-AD-UNIT-ID';
```

---

## Important Notes

⚠️ **Never Test with Real Ad Unit IDs**
- Using test device traffic with live ad unit IDs can result in account suspension
- Always use `useTestAd: true` during development

⚠️ **Ad Refresh Rate**
- Ad impressions are counted after the first page load
- Multiple rapid reloads may not show ads

⚠️ **Platform-Specific Behavior**
- Desktop platforms return `SizedBox.shrink()` (empty widget)
- Mobile platforms show banner at bottom of statistics page
- If ad fails to load, a placeholder is shown for 50ms

---

## Testing Checklist

### Development (with Test Ads)
- [ ] Run on Android emulator - banner should appear
- [ ] Run on iOS simulator - banner should appear  
- [ ] Run on Windows/Linux/macOS - no banner shown
- [ ] Check that statistics page loads normally

### Before Production
- [ ] Get real AdMob App ID and Ad Unit IDs
- [ ] Update `admob_service.dart` with real IDs
- [ ] Change `useTestAd: false` in `thong_ke.dart`
- [ ] Test on real Android device
- [ ] Test on real iOS device
- [ ] Monitor AdMob dashboard for impressions

---

## Troubleshooting

### Ads Not Showing?
1. Check AdMob account status (might need verification)
2. Verify Ad Unit ID is correct
3. Ensure app is built in **Release mode** (test ads work in debug too, but live ads require release)
4. Wait a few minutes - ads take time to load from AdMob servers

### Build Errors?
```bash
flutter pub get
flutter clean
flutter pub get
flutter run
```

### Ad Fails to Load
Check `flutter logs` for error messages:
```bash
flutter logs
```

Look for messages like `"Banner ad failed to load: ..."`

---

## File Locations

- **Ad Service**: `lib/services/admob_service.dart`
- **Ad Widget**: `lib/widgets/admob_banner_widget.dart`
- **App Initialization**: `lib/main.dart` (line ~42)
- **Statistics Page**: `lib/thong_ke.dart` (bottom of ListView)
