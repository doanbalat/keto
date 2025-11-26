# APK Size Optimization Guide

This document outlines all the optimizations applied to reduce the APK size of the Keto app.

## ✅ Implemented Optimizations

### 1. ProGuard & R8 Optimization
- **Location**: `android/app/build.gradle.kts`
- **Features**:
  - R8 full mode enabled for maximum shrinking
  - Code minification and obfuscation
  - Resource shrinking
  - Dead code elimination
  - Custom ProGuard rules for Flutter compatibility

### 2. APK Splitting by ABI
- **Location**: `android/app/build.gradle.kts`
- **Benefits**: Reduces individual APK size by ~40%
- **Supported ABIs**:
  - `armeabi-v7a` (32-bit ARM) - Older devices
  - `arm64-v8a` (64-bit ARM) - Modern devices (required by Play Store)
  - `x86_64` (64-bit Intel) - Emulators/ChromeOS
- **Universal APK**: Also generates a single APK containing all ABIs for testing

### 3. Build Configuration Optimizations
- **Location**: `android/gradle.properties`
- **Enabled**:
  - Gradle parallel builds
  - Build caching
  - Configure on demand
  - R8 full mode
  - D8 dexer (faster than DX)

### 4. PNG Compression
- **Location**: `android/app/build.gradle.kts`
- `isCrunchPngs = true` - Automatically compresses PNG assets

### 5. Multi-Dex Support
- **Location**: `android/app/build.gradle.kts`
- Enables 64K+ method support without increasing APK size unnecessarily

## 📊 Expected APK Sizes

**Before Optimization** (Single Universal APK):
- ~45-60 MB

**After Optimization** (Split APKs):
- arm64-v8a: ~20-25 MB (most common)
- armeabi-v7a: ~18-22 MB
- x86_64: ~22-28 MB
- Universal: ~55-65 MB (all ABIs combined)

**Download Size on Play Store**: ~15-20 MB (compressed + split by ABI)

## 🏗️ Building Optimized Release APKs

### Build Split APKs (Recommended for Play Store)
```bash
flutter build apk --release --split-per-abi
```
Output: `build/app/outputs/flutter-apk/`
- `app-armeabi-v7a-release.apk`
- `app-arm64-v8a-release.apk`
- `app-x86_64-release.apk`

### Build Universal APK (For Testing)
```bash
flutter build apk --release
```
Output: `build/app/outputs/flutter-apk/app-release.apk`

### Build App Bundle (Best for Play Store)
```bash
flutter build appbundle --release
```
Output: `build/app/outputs/bundle/release/app-release.aab`

**Benefits of App Bundle**:
- Play Store automatically generates optimized APKs per device
- Smallest possible download size per user
- Dynamic feature modules support
- Required for Play Console submission

## 🎯 Additional Optimization Tips

### 1. Image Assets
- Use WebP format instead of PNG/JPEG (better compression)
- Provide resolution-specific variants (1x, 2x, 3x)
- Remove unused images from `assets/images/`

### 2. Font Optimization
- Only include required font weights
- Subset fonts to include only used characters
- Consider using system fonts when possible

### 3. Dependency Audit
```bash
flutter pub deps --no-dev
```
Review and remove unused dependencies.

### 4. Code Analysis
```bash
flutter analyze
```
Fix warnings to improve tree-shaking.

### 5. Build Size Analysis
```bash
flutter build apk --analyze-size --target-platform android-arm64
```
Generates detailed size breakdown.

### 6. Asset Compression
Manually optimize images before adding:
```bash
# PNG optimization
pngquant --quality=65-80 input.png -o output.png

# JPEG optimization  
jpegoptim --max=85 image.jpg

# Convert to WebP
cwebp -q 80 input.png -o output.webp
```

## 🔍 APK Content Analysis

### View APK Contents
```bash
cd build/app/outputs/flutter-apk
unzip -l app-release.apk
```

### Largest Components (Typical):
1. **lib/** - Native libraries (30-40%)
   - `libflutter.so` - Flutter engine
   - `libapp.so` - Dart code
   
2. **assets/flutter_assets/** - App assets (20-30%)
   - Images, fonts, data files
   
3. **classes.dex** - Java/Kotlin code (10-15%)
   - App + dependencies

4. **resources.arsc** - Android resources (5-10%)
   - Layouts, strings, styles

## 🚀 Performance vs Size Trade-offs

### Current Configuration (Balanced)
- ✅ ProGuard enabled
- ✅ R8 full mode
- ✅ Resource shrinking
- ✅ APK splitting
- ❌ Aggressive compression (may slow app startup)

### Aggressive Optimization (Smaller but Slower)
To reduce size further, add to `build.gradle.kts`:
```kotlin
packagingOptions {
    resources.excludes.add("META-INF/**")
    resources.excludes.add("kotlin/**")
    doNotStrip("*/armeabi-v7a/*.so")
    doNotStrip("*/arm64-v8a/*.so")
}
```

⚠️ **Note**: This may increase app startup time.

## 📱 Play Store Recommendations

1. **Use App Bundle** (.aab) for submission
2. **Enable split APKs** by ABI and density
3. **Test on real devices** before releasing
4. **Monitor size metrics** in Play Console
5. **Target Android 12+ features** for better optimization

## 🔧 Troubleshooting

### Build Fails with R8 Errors
Check `android/app/proguard-rules.pro` for missing keep rules.

### APK Too Large
1. Run `flutter build apk --analyze-size`
2. Check for large assets in `assets/`
3. Remove unused dependencies
4. Use split APKs

### App Crashes After ProGuard
Add missing ProGuard rules for reflection-based libraries.

## 📚 References

- [Flutter Size Optimization](https://docs.flutter.dev/perf/app-size)
- [Android App Bundle](https://developer.android.com/guide/app-bundle)
- [R8 Shrinking](https://developer.android.com/build/shrink-code)
- [ProGuard Rules](https://www.guardsquare.com/manual/configuration/usage)
