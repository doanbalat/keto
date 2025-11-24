import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../models/product_model.dart';
import '../models/sold_item_model.dart';
import '../models/expense_model.dart';

enum ExportFormat { json, csv }

class ExportService {
  // Export to JSON format
  static Future<String> exportToJson({
    required List<Product> products,
    required List<SoldItem> soldItems,
    required List<Expense> expenses,
  }) async {
    final data = {
      'exportDate': DateTime.now().toIso8601String(),
      'appVersion': '1.0.0',
      'summary': {
        'totalProducts': products.length,
        'totalSoldItems': soldItems.length,
        'totalExpenses': expenses.length,
        'totalRevenue': soldItems.fold<int>(0, (sum, item) => sum + item.totalPrice),
        'totalExpensesAmount': expenses.fold<int>(0, (sum, exp) => sum + exp.amount),
      },
      'products': products.map((p) => p.toMap()).toList(),
      'soldItems': soldItems.map((s) => _formatSoldItemForExport(s)).toList(),
      'expenses': expenses.map((e) => e.toMap()).toList(),
    };

    return jsonEncode(data);
  }

  // Export to CSV format
  static Future<String> exportToCsv({
    required List<Product> products,
    required List<SoldItem> soldItems,
    required List<Expense> expenses,
  }) async {
    final buffer = StringBuffer();

    // Products section
    buffer.writeln('=== SẢN PHẨM (PRODUCTS) ===');
    buffer.writeln('ID,Tên,Giá,Giá vốn,Kho,Danh mục,Đơn vị,Ngày tạo');
    for (var product in products) {
      buffer.writeln(
        '"${product.id}","${product.name}","${product.price}","${product.costPrice}","${product.stock}","${product.category}","${product.unit}","${product.createdAt}"',
      );
    }
    buffer.writeln('');

    // Sold Items section
    buffer.writeln('=== BÁN HÀNG (SALES) ===');
    buffer.writeln(
      'ID,Sản phẩm,Số lượng,Đơn giá,Thành tiền,Giảm giá,Thực nhận,Phương thức,Ghi chú,Khách hàng,Ngày bán',
    );
    for (var item in soldItems) {
      final productName = item.product?.name ?? 'Unknown';
      final productPrice = item.product?.price ?? 0;
      buffer.writeln(
        '"${item.id}","$productName","${item.quantity}","$productPrice","${item.totalPrice}","${item.discount}","${item.priceAfterDiscount}","${item.paymentMethod}","${item.note ?? ''}","${item.customerName ?? ''}","${item.timestamp}"',
      );
    }
    buffer.writeln('');

    // Expenses section
    buffer.writeln('=== CHI PHÍ (EXPENSES) ===');
    buffer.writeln('ID,Danh mục,Mô tả,Số tiền,Phương thức,Ghi chú,Ngày');
    for (var expense in expenses) {
      buffer.writeln(
        '"${expense.id}","${expense.category}","${expense.description}","${expense.amount}","${expense.paymentMethod}","${expense.note ?? ''}","${expense.timestamp}"',
      );
    }

    return buffer.toString();
  }

  // Save export file and return file path
  static Future<File> saveExportFile(
    String content,
    ExportFormat format,
  ) async {
    late Directory directory;
    
    try {
      // Get the app-specific external files directory
      // Android: /storage/emulated/0/Android/data/com.example.keto/files
      // This is accessible via Files app: Internal Storage > Android > Data > com.example.keto > files
      final externalCacheDir = await getExternalCacheDirectories();
      if (externalCacheDir != null && externalCacheDir.isNotEmpty) {
        // Navigate up from cache to files directory
        // /storage/emulated/0/Android/data/com.example.keto/cache -> /storage/emulated/0/Android/data/com.example.keto/files
        final cachePath = externalCacheDir.first.path;
        final filesPath = cachePath.replaceAll('/cache', '/files');
        directory = Directory(filesPath);
        if (kDebugMode) print('📂 Using external files directory: ${directory.path}');
      } else {
        throw Exception('External cache directory not available');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error getting external files directory: $e');
      try {
        // Fallback to app documents directory
        directory = await getApplicationDocumentsDirectory();
        if (kDebugMode) print('📂 Fallback to app documents directory: ${directory.path}');
      } catch (e2) {
        if (kDebugMode) print('❌ Error getting app documents: $e2');
        directory = await getTemporaryDirectory();
        if (kDebugMode) print('📂 Fallback to temp directory: ${directory.path}');
      }
    }

    // Ensure directory exists
    if (!await directory.exists()) {
      try {
        await directory.create(recursive: true);
        if (kDebugMode) print('✅ Created directory: ${directory.path}');
      } catch (e) {
        if (kDebugMode) print('❌ Could not create directory: $e');
        throw Exception('Cannot create directory: $e');
      }
    } else {
      if (kDebugMode) print('✅ Directory already exists: ${directory.path}');
    }

    final timestamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
    final extension = _getFileExtension(format);
    final fileName = 'keto_export_$timestamp.$extension';
    final filePath = '${directory.path}/$fileName';

    if (kDebugMode) print('📝 Attempting to save file to: $filePath');
    if (kDebugMode) print('📊 Content size: ${content.length} characters');

    try {
      final file = File(filePath);
      
      // Write the file
      await file.writeAsString(content);
      if (kDebugMode) print('✅ Write operation completed');
      
      // Verify the file exists
      final exists = await file.exists();
      if (!exists) {
        throw Exception('File was not created after write operation');
      }
      if (kDebugMode) print('✅ File exists verification passed');
      
      // Get file size
      final fileSize = await file.length();
      if (kDebugMode) print('✅ File size: $fileSize bytes');
      
      if (fileSize == 0) {
        throw Exception('File is empty after write');
      }
      if (kDebugMode) print('✅ File is not empty');
      
      // Read first 100 characters to verify content
      final firstChars = await file.readAsString().then((c) => c.substring(0, (c.length < 100 ? c.length : 100)));
      if (kDebugMode) print('✅ File content verified (first 100 chars): $firstChars');
      
      if (kDebugMode) print('✅✅✅ File saved successfully at: $filePath');
      return file;
    } catch (e) {
      if (kDebugMode) print('❌❌❌ Error writing file: $e');
      if (kDebugMode) print('Stack trace: $e');
      rethrow;
    }
  }

  // Get file extension based on format
  static String _getFileExtension(ExportFormat format) {
    switch (format) {
      case ExportFormat.json:
        return 'json';
      case ExportFormat.csv:
        return 'csv';
    }
  }

  // Get format display name
  static String getFormatDisplayName(ExportFormat format) {
    switch (format) {
      case ExportFormat.json:
        return 'JSON (Data Backup)';
      case ExportFormat.csv:
        return 'CSV (Excel Compatible)';
    }
  }

  // Helper method to format SoldItem for export
  static Map<String, dynamic> _formatSoldItemForExport(SoldItem item) {
    return {
      'id': item.id,
      'productId': item.productId,
      'productName': item.product?.name ?? 'Unknown',
      'quantity': item.quantity,
      'unitPrice': item.product?.price ?? 0,
      'totalPrice': item.totalPrice,
      'discount': item.discount,
      'priceAfterDiscount': item.priceAfterDiscount,
      'paymentMethod': item.paymentMethod,
      'timestamp': item.timestamp.toIso8601String(),
      'note': item.note,
      'customerName': item.customerName,
    };
  }
}
