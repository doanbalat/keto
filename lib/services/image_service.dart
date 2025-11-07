import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class ImageService {
  /// Save image file to app's documents directory and return the file path
  /// 
  /// This function:
  /// 1. Gets the app's documents directory
  /// 2. Creates a 'product_images' subdirectory if it doesn't exist
  /// 3. Copies the selected image to that directory with a unique name
  /// 4. Returns the full path to the saved image
  /// 
  /// Returns: Full path to saved image, or null if operation fails
  static Future<String?> saveProductImage(File imageFile) async {
    try {
      // Get app's documents directory
      final appDocDir = await getApplicationDocumentsDirectory();
      
      // Create product_images subdirectory
      final productImagesDir = Directory(
        path.join(appDocDir.path, 'product_images'),
      );
      
      if (!await productImagesDir.exists()) {
        await productImagesDir.create(recursive: true);
      }
      
      // Generate unique filename using timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'product_$timestamp.jpg';
      final savedImagePath = path.join(productImagesDir.path, fileName);
      
      // Copy image file to the new location
      final savedImage = await imageFile.copy(savedImagePath);
      
      print('Image saved successfully to: ${savedImage.path}');
      return savedImage.path;
    } catch (e) {
      print('Error saving product image: $e');
      return null;
    }
  }
  
  /// Delete product image file from storage
  /// 
  /// Returns: true if deletion successful, false otherwise
  static Future<bool> deleteProductImage(String imagePath) async {
    try {
      final imageFile = File(imagePath);
      if (await imageFile.exists()) {
        await imageFile.delete();
        print('Image deleted successfully: $imagePath');
        return true;
      }
      return false;
    } catch (e) {
      print('Error deleting product image: $e');
      return false;
    }
  }
  
  /// Check if image file exists
  static Future<bool> imageExists(String imagePath) async {
    try {
      final imageFile = File(imagePath);
      return await imageFile.exists();
    } catch (e) {
      print('Error checking image existence: $e');
      return false;
    }
  }
}
