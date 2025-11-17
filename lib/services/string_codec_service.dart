import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import '../models/product_model.dart';
import '../models/sold_item_model.dart';
import '../models/expense_model.dart';

/// Keto String Codec Service - Similar to Factorio blueprint strings
/// Encodes/decodes app data to/from compressed strings for easy sharing
class StringCodecService {
  // Version for future compatibility
  static const int version = 1;

  // String prefix to identify Keto import strings
  static const String prefix = 'KETO';

  /// Encode data (products, sold items, expenses) into a compact string
  static String encodeToString({
    required List<Product> products,
    required List<SoldItem> soldItems,
    required List<Expense> expenses,
  }) {
    try {
      // Create data structure
      final data = {
        'v': version, // Version
        'p': _encodeProducts(products),
        's': _encodeSoldItems(soldItems),
        'e': _encodeExpenses(expenses),
      };

      // Convert to JSON
      final jsonString = jsonEncode(data);

      // Compress with gzip
      final jsonBytes = utf8.encode(jsonString);
      final compressed = gzip.encode(jsonBytes);

      // Encode to base64
      final base64String = base64Encode(compressed);

      // Add prefix and checksum
      final checksum = _calculateChecksum(base64String);
      final finalString = '$prefix$version$checksum$base64String';

      print('✅ Encoded string (${finalString.length} chars): ${finalString.substring(0, 50)}...');
      return finalString;
    } catch (e) {
      print('❌ Error encoding: $e');
      rethrow;
    }
  }

  /// Decode string back to data
  static Map<String, dynamic> decodeFromString(String encodedString) {
    try {
      // Validate prefix
      if (!encodedString.startsWith(prefix)) {
        throw Exception('Invalid import string format. Must start with "$prefix"');
      }

      // Extract version and checksum
      final decodedVersion = int.parse(encodedString[4]);
      final checksum = encodedString.substring(5, 13);
      final base64String = encodedString.substring(13);

      // Verify checksum
      final expectedChecksum = _calculateChecksum(base64String);
      if (checksum != expectedChecksum) {
        throw Exception('Checksum validation failed. Import string may be corrupted.');
      }

      if (decodedVersion != version) {
        throw Exception('Unsupported version: $decodedVersion (expected $version)');
      }

      // Decode from base64
      final compressed = base64Decode(base64String);

      // Decompress with gzip
      final jsonString = utf8.decode(gzip.decode(compressed));

      // Parse JSON
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      return {
        'products': _decodeProducts(data['p'] as List<dynamic>? ?? []),
        'soldItems': _decodeSoldItems(data['s'] as List<dynamic>? ?? []),
        'expenses': _decodeExpenses(data['e'] as List<dynamic>? ?? []),
      };
    } catch (e) {
      print('❌ Error decoding: $e');
      rethrow;
    }
  }

  // ==================== ENCODING ====================

  static List<Map<String, dynamic>> _encodeProducts(List<Product> products) {
    return products.map((p) => {
      'i': p.id,
      'n': p.name,
      'pr': p.price,
      'cp': p.costPrice,
      'st': p.stock,
      'ca': p.category,
      'u': p.unit,
      'd': p.description,
      'ct': p.createdAt.millisecondsSinceEpoch,
      'a': p.isActive ? 1 : 0,
    }).toList();
  }

  static List<Map<String, dynamic>> _encodeSoldItems(List<SoldItem> items) {
    return items.map((s) => {
      'i': s.id,
      'pi': s.productId,
      'q': s.quantity,
      'tp': s.totalPrice,
      'pm': s.paymentMethod,
      'dis': s.discount,
      'n': s.note,
      'cn': s.customerName,
      'ts': s.timestamp.millisecondsSinceEpoch,
    }).toList();
  }

  static List<Map<String, dynamic>> _encodeExpenses(List<Expense> expenses) {
    return expenses.map((e) => {
      'i': e.id,
      'ca': e.category,
      'd': e.description,
      'a': e.amount,
      'ts': e.timestamp.millisecondsSinceEpoch,
      'pm': e.paymentMethod,
      'n': e.note,
    }).toList();
  }

  // ==================== DECODING ====================

  static List<Product> _decodeProducts(List<dynamic> data) {
    return data.map((p) {
      final map = p as Map<String, dynamic>;
      return Product(
        id: map['i'] as int? ?? 0,
        name: map['n'] as String? ?? 'Unknown',
        price: map['pr'] as int? ?? 0,
        costPrice: map['cp'] as int? ?? 0,
        stock: map['st'] as int? ?? 0,
        category: map['ca'] as String? ?? 'Khác',
        unit: map['u'] as String? ?? 'cái',
        description: map['d'] as String?,
        createdAt: map['ct'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['ct'] as int)
          : DateTime.now(),
        isActive: (map['a'] as int? ?? 1) == 1,
      );
    }).toList();
  }

  static List<SoldItem> _decodeSoldItems(List<dynamic> data) {
    return data.map((s) {
      final map = s as Map<String, dynamic>;
      return SoldItem(
        id: map['i'] as int? ?? 0,
        productId: map['pi'] as int? ?? 0,
        quantity: map['q'] as int? ?? 0,
        totalPrice: map['tp'] as int? ?? 0,
        paymentMethod: map['pm'] as String? ?? 'Tiền mặt',
        discount: map['dis'] as int? ?? 0,
        note: map['n'] as String?,
        customerName: map['cn'] as String?,
        timestamp: map['ts'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['ts'] as int)
          : DateTime.now(),
      );
    }).toList();
  }

  static List<Expense> _decodeExpenses(List<dynamic> data) {
    return data.map((e) {
      final map = e as Map<String, dynamic>;
      return Expense(
        id: map['i'] as int? ?? 0,
        category: map['ca'] as String? ?? 'Khác',
        description: map['d'] as String? ?? '',
        amount: map['a'] as int? ?? 0,
        paymentMethod: map['pm'] as String? ?? 'Tiền mặt',
        note: map['n'] as String?,
        timestamp: map['ts'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['ts'] as int)
          : DateTime.now(),
      );
    }).toList();
  }

  // ==================== CHECKSUM ====================

  /// Calculate MD5 checksum for verification (first 8 chars)
  static String _calculateChecksum(String data) {
    final hash = md5.convert(utf8.encode(data)).toString();
    return hash.substring(0, 8);
  }

  /// Get stats about encoded data
  static Map<String, int> getEncodedStats(String encodedString) {
    try {
      final decoded = decodeFromString(encodedString);
      return {
        'products': (decoded['products'] as List).length,
        'soldItems': (decoded['soldItems'] as List).length,
        'expenses': (decoded['expenses'] as List).length,
        'stringLength': encodedString.length,
      };
    } catch (_) {
      return {};
    }
  }
}
