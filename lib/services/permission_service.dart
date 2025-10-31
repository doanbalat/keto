import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  /// Request camera permission
  static Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  /// Request photo library permission
  static Future<bool> requestPhotoLibraryPermission() async {
    // Try photos permission first (Android 13+/iOS)
    final status = await Permission.photos.request();
    print('Photo permission status after request: $status');

    // Re-check the actual permission status after request
    final finalStatus = await Permission.photos.status;
    print('Photo permission final status: $finalStatus');

    // Accept both granted and limited (iOS partial access)
    if (finalStatus.isGranted || finalStatus.isLimited) {
      return true;
    }

    // Fallback: Try storage permission (Android 12 and below)
    final storageStatus = await Permission.storage.request();
    print('Storage permission status after request: $storageStatus');
    return storageStatus.isGranted;
  }

  /// Request storage permission (Android)
  static Future<bool> requestStoragePermission() async {
    final status = await Permission.storage.request();
    return status.isGranted;
  }

  /// Check if camera permission is granted
  static Future<bool> isCameraPermissionGranted() async {
    final status = await Permission.camera.status;
    return status.isGranted;
  }

  /// Check if photo library permission is granted
  static Future<bool> isPhotoLibraryPermissionGranted() async {
    // Check photos permission (Android 13+/iOS)
    final photosStatus = await Permission.photos.status;
    if (photosStatus.isGranted || photosStatus.isLimited) {
      return true;
    }

    // Fallback: check storage permission (Android 12 and below)
    final storageStatus = await Permission.storage.status;
    return storageStatus.isGranted;
  }

  /// Check if storage permission is granted (Android)
  static Future<bool> isStoragePermissionGranted() async {
    final status = await Permission.storage.status;
    return status.isGranted;
  }

  /// Request all necessary permissions for the app
  /// Note: iOS automatically grants app sandbox storage access
  /// Android requires explicit storage permission request
  static Future<bool> requestAllPermissions() async {
    try {
      // Request storage permissions for database (Android only)
      // iOS uses automatic app sandbox storage - no permission needed
      await requestStoragePermission();

      // Request camera permission for image picker
      await requestCameraPermission();

      // Request photo library permission for image picker
      await requestPhotoLibraryPermission();

      print('Permissions requested successfully');
      return true;
    } catch (e) {
      print('Error requesting permissions: $e');
      return false;
    }
  }

  /// Open app settings to allow user to enable permissions manually
  static Future<bool> openSettings() async {
    return await openAppSettings();
  }

  /// Get permission status summary
  static Future<String> getPermissionsSummary() async {
    final cameraGranted = await isCameraPermissionGranted();
    final photoGranted = await isPhotoLibraryPermissionGranted();
    final storageGranted = await isStoragePermissionGranted();

    return '''
Permission Status:
- Camera: ${cameraGranted ? '✓ Granted' : '✗ Denied'}
- Photo Library: ${photoGranted ? '✓ Granted' : '✗ Denied'}
- Storage (Android only): ${storageGranted ? '✓ Granted' : '✗ Denied (N/A on iOS)'}

Note: iOS automatically grants app sandbox access for database storage
    ''';
  }
}
