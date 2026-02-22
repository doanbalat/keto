plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
}

// Load key.properties for release signing (if it exists)
val keystorePropsFile = rootProject.file("../key.properties")
val hasKeystoreProps = keystorePropsFile.exists()

android {
    namespace = "com.doanbalat.keto"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        // Enable core library desugaring for Java 8+ features
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.doanbalat.keto"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // Enable multi-dex support for apps with 64K+ methods
        multiDexEnabled = true
        
        // Split APKs by ABI to reduce download size
        ndk {
            abiFilters.addAll(listOf("armeabi-v7a", "arm64-v8a", "x86_64"))
        }
    }

    signingConfigs {
        if (hasKeystoreProps) {
            create("release") {
                val lines = keystorePropsFile.readLines()
                val propsMap = lines
                    .filter { it.isNotBlank() && !it.startsWith("#") && it.contains("=") }
                    .associate { 
                        val (key, value) = it.split("=", limit = 2)
                        key.trim() to value.trim().removeSurrounding("\"")
                    }
                
                keyAlias = propsMap["keyAlias"] ?: ""
                keyPassword = propsMap["keyPassword"] ?: ""
                storeFile = propsMap["storeFile"]?.let { rootProject.file("../${it}") }
                storePassword = propsMap["storePassword"] ?: ""
            }
        }
    }

    buildTypes {
        release {
            // Use release signing config if key.properties exists
            if (hasKeystoreProps) {
                signingConfig = signingConfigs.getByName("release")
            }
            
            // Enable ProGuard minification and code obfuscation for production
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            
            // Optimize for size
            isCrunchPngs = true // Compress PNG files
        }
        
        debug {
            // Disable optimizations for faster debug builds
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
    
    // Note: ABI splits should NOT be used with app bundles
    // App bundles handle multi-APK generation automatically
}

dependencies {
    // Core library desugaring for Java 8+ features
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.3")
    
    // Firebase BOM for version management
    implementation(platform("com.google.firebase:firebase-bom:33.6.0"))
    
    // Multidex support
    implementation("androidx.multidex:multidex:2.0.1")
}

flutter {
    source = "../.."
}
