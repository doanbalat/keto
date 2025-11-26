# Firebase Setup Instructions

## Step 1: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add project" or select an existing project
3. Enter project name (e.g., "Keto App")
4. Enable Google Analytics (recommended for better insights)
5. Create project

## Step 2: Add Android App to Firebase

1. In Firebase Console, click "Add app" and select Android (the Android icon)
2. **Android package name**: Enter `com.doanbalat.keto` (MUST match your app package)
3. **App nickname** (optional): Enter "Keto"
4. **Debug signing certificate SHA-1** (optional, but recommended for future features):
   - Open PowerShell in your project folder
   - Run: `cd android; .\gradlew signingReport`
   - Copy the SHA-1 from "Variant: debug" section
   - Paste it in Firebase Console
5. Click "Register app"

## Step 3: Download Configuration File

1. Click "Download google-services.json" button
2. Save the file
3. **IMPORTANT**: Move `google-services.json` to:
   ```
   D:\MyCode\Flutter\keto\android\app\
   ```
4. Click "Next" in Firebase Console

## Step 4: Verify Configuration

The build configuration is already set up with:
- Firebase SDK dependencies in build.gradle.kts
- google-services plugin enabled
- Firebase Crashlytics plugin enabled

## Step 5: Enable Firebase Services

### Enable Crashlytics:
1. In Firebase Console, go to "Crashlytics" in the left menu
2. Click "Enable Crashlytics"
3. Wait for the service to be enabled

### Enable Analytics:
1. In Firebase Console, go to "Analytics" in the left menu
2. Analytics should already be enabled (if you enabled it during project creation)

## Step 6: Build and Test

1. Build the app: `flutter build apk --debug`
2. Install on a device: `flutter install`
3. Open the app and use it normally
4. To test crash reporting (optional, debug only):
   - Add this temporary code in any screen:
   ```dart
   import 'services/firebase_service.dart';
   
   // In a button onPressed:
   if (kDebugMode) {
     FirebaseService.testCrash();
   }
   ```
5. Wait a few minutes and check Firebase Console > Crashlytics for the crash report

## File Structure After Setup

```
android/
  app/
    google-services.json  ← Place the downloaded file here
    build.gradle.kts      ✓ Already configured
    proguard-rules.pro    ✓ Already configured
  build.gradle.kts        ✓ Already configured
```

## What's Already Configured

✅ Firebase Core, Crashlytics, and Analytics dependencies added to pubspec.yaml
✅ Firebase plugins enabled in android/app/build.gradle.kts
✅ Firebase classpath dependencies in android/build.gradle.kts
✅ Firebase initialization in lib/main.dart
✅ Firebase service wrapper created in lib/services/firebase_service.dart
✅ ProGuard rules for Firebase in android/app/proguard-rules.pro

## What You Need to Do

❌ Create Firebase project
❌ Download google-services.json
❌ Place google-services.json in android/app/
❌ Enable Crashlytics in Firebase Console

## Next Steps After Firebase Setup

Once google-services.json is in place:
1. Run `flutter clean`
2. Run `flutter build apk --release`
3. Test the release APK
4. Firebase will start collecting crash reports automatically

## Features Available

### Automatic Crash Reporting
- All uncaught errors automatically sent to Firebase
- Stack traces for debugging
- Device info and app version included

### Manual Error Logging
```dart
try {
  // risky code
} catch (e, stack) {
  await FirebaseService.logError(e, stack, reason: 'Failed to save product');
}
```

### Analytics Events
```dart
await FirebaseService.logEvent('product_added', parameters: {
  'product_name': productName,
  'price': price,
});
```

### Screen Tracking
```dart
@override
void initState() {
  super.initState();
  FirebaseService.logScreenView('Product Management');
}
```

## Troubleshooting

### Build Error: "File google-services.json is missing"
- Make sure google-services.json is in `android/app/` (not `android/`)
- Run `flutter clean` and rebuild

### Crashes Not Appearing in Console
- Wait 5-10 minutes for first crash to appear
- Make sure Crashlytics is enabled in Firebase Console
- Check that google-services.json has correct package name

### SHA-1 Certificate Error (future)
- Required for Firebase Authentication, Dynamic Links, etc.
- Not required for Crashlytics/Analytics
- Can add later when needed

## Security Notes

- ✅ google-services.json is already in .gitignore
- ✅ Firebase API keys in google-services.json are public (safe to commit)
- ✅ Access restricted by package name and SHA-1 fingerprint
- ⚠️ Do NOT commit your release keystore (key.properties)
