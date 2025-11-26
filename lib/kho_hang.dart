import 'package:flutter/material.dart';
import 'dart:io';
import 'package:responsive_builder/responsive_builder.dart';
import 'models/product_model.dart';
import 'services/product_service.dart';
import 'services/image_service.dart';
import 'services/permission_service.dart';
import 'services/notification_service.dart';
import 'services/firebase_service.dart';
import 'services/currency_service.dart';
import 'services/localization_service.dart';
import 'services/product_category_service.dart';
import 'services/statistics_cache_service.dart';
import 'package:image_picker/image_picker.dart';

class InventoryPage extends StatefulWidget {
  final int lowStockThreshold;
  final ProductService? productService;

  const InventoryPage({
    super.key,
    this.lowStockThreshold = 5,
    this.productService,
  });

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  late final ProductService _productService;
  final TextEditingController _searchController = TextEditingController();

  List<Product> allProducts = [];
  List<Product> filteredProducts = [];
  List<String>? _cachedCategories;

  bool _isLoading = true;
  String?
  _activeFilter; // Track active filter: 'all', 'inStock', 'outOfStock', 'lowStock'
  String _sortBy = 'none'; // 'none', 'name', 'quantity'
  bool _sortAscending = true; // true for ascending, false for descending
  String? _selectedCategory; // Category filter

  @override
  void initState() {
    super.initState();
    // Log screen view to Analytics
    FirebaseService.logScreenView('Inventory Page');
    _productService = widget.productService ?? ProductService();
    _loadProducts();
    _searchController.addListener(_filterProducts);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    try {
      final products = await _productService.getAllProducts();
      setState(() {
        allProducts = products;
        filteredProducts = products;
        _activeFilter = null; // Reset filter on refresh
        _sortBy = 'none'; // Reset sort
        _sortAscending = true; // Reset sort order
        _selectedCategory = null; // Reset category filter
        _cachedCategories = null; // Reset cached categories
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading products: $e')));
    }
  }

  void _filterProducts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      filteredProducts = allProducts.where((product) {
        // First check search query
        final matchesSearch = product.name.toLowerCase().contains(query);
        if (!matchesSearch) return false;

        // Apply category filter if selected
        if (_selectedCategory != null && _selectedCategory != LocalizationService.getString('inventory_all_categories')) {
          if (product.category != _selectedCategory) return false;
        }

        // Then apply active filter
        if (_activeFilter == null || _activeFilter == 'all') {
          return true;
        } else if (_activeFilter == 'inStock') {
          return product.stock > widget.lowStockThreshold;
        } else if (_activeFilter == 'outOfStock') {
          return product.stock == 0;
        } else if (_activeFilter == 'lowStock') {
          return product.stock > 0 && product.stock <= widget.lowStockThreshold;
        }
        return true;
      }).toList();

      // Apply sorting
      if (_sortBy == 'name') {
        filteredProducts.sort((a, b) => a.name.compareTo(b.name));
        if (!_sortAscending) {
          filteredProducts = filteredProducts.reversed.toList();
        }
      } else if (_sortBy == 'quantity') {
        filteredProducts.sort((a, b) => a.stock.compareTo(b.stock));
        if (!_sortAscending) {
          filteredProducts = filteredProducts.reversed.toList();
        }
      }
    });
  }

  Color _getStockIndicatorColor(int quantity) {
    if (quantity == 0) return Colors.redAccent;
    if (quantity <= widget.lowStockThreshold) return Colors.orange;
    return Colors.green;
  }

  String _getStockStatus(int quantity) {
    if (quantity == 0) return LocalizationService.getString('inventory_out_of_stock');
    if (quantity <= widget.lowStockThreshold) return LocalizationService.getString('inventory_low_stock');
    return LocalizationService.getString('inventory_in_stock');
  }

  int _getTotalInventoryValue() {
    return allProducts.fold<int>(
      0,
      (sum, product) => sum + (product.stock * product.price),
    );
  }

  int _getProductsInStock() {
    return allProducts.where((p) => p.stock > widget.lowStockThreshold).length;
  }

  int _getProductsOutOfStock() {
    return allProducts.where((p) => p.stock == 0).length;
  }

  int _getLowStockProducts() {
    return allProducts.where((p) => p.stock > 0 && p.stock <= widget.lowStockThreshold).length;
  }

  List<String> _getUniqueCategories() {
    if (_cachedCategories != null) {
      return _cachedCategories!;
    }
    final categories = <String>{LocalizationService.getString('inventory_all_categories')};
    for (var product in allProducts) {
      categories.add(product.category);
    }
    _cachedCategories = categories.toList()..sort();
    return _cachedCategories!;
  }

  Future<void> _checkAndNotifyLowStock(Product product) async {
    // Only show notification if stock is above 0 and at or below threshold
    if (product.stock > 0 && product.stock <= widget.lowStockThreshold) {
      try {
        final NotificationService notificationService = NotificationService();
        await notificationService.showWarning(
          LocalizationService.getString('inventory_low_stock_notification'),
          '${product.name} chỉ còn ${product.stock} ${product.unit}',
        );
        print('Low stock notification sent for: ${product.name}, stock: ${product.stock}');
      } catch (e) {
        print('Error showing low stock notification: $e');
      }
    }
  }

  void _showAdjustStockDialog(Product product) {
    final quantityController = TextEditingController(
      text: product.stock.toString(),
    );
    final unitController = TextEditingController(text: product.unit);
    int currentValue = product.stock;
    File? selectedImage;
    final ImagePicker _picker = ImagePicker();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final difference = currentValue - product.stock;
            final isIncreasing = difference > 0;

            return AlertDialog(
              title: Text('${LocalizationService.getString('inventory_update_title')} - ${product.name}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image picker section
                    GestureDetector(
                      onTap: () async {
                        // Check if permission is already granted
                        bool hasPermission =
                            await PermissionService.isPhotoLibraryPermissionGranted();

                        // If not granted, request permission
                        if (!hasPermission) {
                          hasPermission =
                              await PermissionService.requestPhotoLibraryPermission();

                          // If still not granted after request, user denied it
                          if (!hasPermission) {
                            if (!mounted) return;
                            showDialog(
                              context: context,
                              builder: (BuildContext ctx) {
                                return AlertDialog(
                                  title: const Text(
                                    'Yêu cầu quyền truy cập',
                                  ),
                                  content: const Text(
                                    'Ứng dụng cần quyền truy cập thư viện ảnh để chọn ảnh sản phẩm. '
                                    'Vui lòng cấp quyền trong cài đặt.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx),
                                      child: Text(LocalizationService.getString('btn_cancel')),
                                    ),
                                    ElevatedButton(
                                      onPressed: () async {
                                        Navigator.pop(ctx);
                                        await PermissionService.openSettings();
                                      },
                                      child: Text(
                                        LocalizationService.getString('btn_open_settings'),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            );
                            return;
                          }
                        }

                        // Permission granted - open image picker
                        final XFile? image = await _picker.pickImage(
                          source: ImageSource.gallery,
                        );
                        if (image != null) {
                          setDialogState(() {
                            selectedImage = File(image.path);
                          });
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        height: 150,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.grey[400]!,
                            width: 2,
                          ),
                        ),
                        child: selectedImage != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.file(
                                  selectedImage!,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : product.imagePath != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.file(
                                  File(product.imagePath!),
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.image_outlined,
                                    size: 48,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    LocalizationService.getString('inventory_select_image_hint'),
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Current stock info
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            LocalizationService.getString('inventory_current_stock'),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            '${product.stock} ${product.unit}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Quick action buttons
                    Text(
                      LocalizationService.getString('inventory_quick_adjust'),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => setDialogState(() {
                              currentValue = (currentValue - 10).clamp(
                                0,
                                999999,
                              );
                              quantityController.text = currentValue.toString();
                            }),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[100],
                              foregroundColor: Colors.red,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            child: const Text(
                              '-10',
                              style: TextStyle(fontSize: 15),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => setDialogState(() {
                              currentValue = (currentValue - 1).clamp(
                                0,
                                999999,
                              );
                              quantityController.text = currentValue.toString();
                            }),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[100],
                              foregroundColor: Colors.red,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            child: const Text(
                              '-1',
                              style: TextStyle(fontSize: 15),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => setDialogState(() {
                              currentValue += 1;
                              quantityController.text = currentValue.toString();
                            }),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[100],
                              foregroundColor: const Color.fromARGB(255, 19, 97, 20),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            child: const Text(
                              '+1',
                              style: TextStyle(fontSize: 15),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => setDialogState(() {
                              currentValue += 10;
                              quantityController.text = currentValue.toString();
                            }),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[100],
                              foregroundColor: const Color.fromARGB(255, 19, 97, 20),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            child: const Text(
                              '+10',
                              style: TextStyle(fontSize: 15),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Main input field
                    TextField(
                      controller: quantityController,
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        setDialogState(() {
                          currentValue = int.tryParse(value) ?? product.stock;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: LocalizationService.getString('inventory_enter_new_quantity'),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        suffixText: unitController.text,
                        counterText: difference == 0
                            ? '~'
                            : '${isIncreasing ? '+' : ''}$difference',
                        counterStyle: TextStyle(
                          color: difference == 0
                              ? Colors.grey
                              : isIncreasing
                              ? Colors.green
                              : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Button to add with different price
                    ElevatedButton.icon(
                      onPressed: () {
                        _showAddStockWithDifferentPriceDialog(
                          context,
                          product,
                          quantityController,
                          setDialogState,
                        );
                      },
                      icon: const Icon(Icons.shopping_cart_checkout),
                      label: Text(LocalizationService.getString('inventory_import_different_price')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Unit input field
                    TextField(
                      controller: unitController,
                      onChanged: (value) {
                        setDialogState(() {
                          // Trigger rebuild to update suffixText
                        });
                      },
                      decoration: InputDecoration(
                        labelText: LocalizationService.getString('inventory_unit_hint'),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.scale),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Price info
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 252, 236, 210),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color.fromARGB(255, 250, 195, 113)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                LocalizationService.getString('inventory_selling_price_label'),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black87,
                                ),
                              ),
                              Text(
                                CurrencyService.formatCurrency(product.price),
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                LocalizationService.getString('inventory_product_label_cost_price') + ':',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black87,
                                ),
                              ),
                              Text(
                                CurrencyService.formatCurrency(product.costPrice),
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Divider(height: 12, color: Colors.orange[200]),
                          Text(
                            '${LocalizationService.getString('inventory_value')}: ${CurrencyService.formatCurrency(product.stock * product.price)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.black87,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(1),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.orange[700],
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              LocalizationService.getString('inventory_average_cost_price_note'),
                              style: TextStyle(
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.grey[300]
                                  : Colors.black54,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(LocalizationService.getString('btn_cancel')),
                        ),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: () async {
                            try {
                              final newQuantity = int.parse(
                                quantityController.text,
                              );
                              final newUnit = unitController.text.isEmpty
                                  ? 'cái'
                                  : unitController.text;

                              if (newQuantity < 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(LocalizationService.getString('inventory_quantity_negative')),
                                  ),
                                );
                                return;
                              }

                              // Save image if a new one was selected
                              String? imagePath = product.imagePath;
                              if (selectedImage != null) {
                                final savedPath =
                                    await ImageService.saveProductImage(
                                  selectedImage!,
                                );
                                if (savedPath == null) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content:
                                          Text(LocalizationService.getString('inventory_save_image_error')),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  return;
                                }
                                imagePath = savedPath;
                              }

                              // Update product with new stock, unit, and optionally new image
                              final updatedProduct = product.copyWith(
                                stock: newQuantity,
                                unit: newUnit,
                                imagePath: imagePath,
                              );
                              await _productService.updateProduct(
                                updatedProduct,
                              );

                              // Invalidate statistics cache when product is updated
                              StatisticsCacheService.invalidateCache();

                              if (!mounted) return;
                              Navigator.pop(context);

                              await _loadProducts();

                              // Check and send low stock notification
                              await _checkAndNotifyLowStock(updatedProduct);

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    LocalizationService.getString('inventory_update_success_simple').replaceAll('{name}', product.name),
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('${LocalizationService.getString('error_with_message')}$e')),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                          child: Text(LocalizationService.getString('btn_save')),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddStockWithDifferentPriceDialog(
    BuildContext context,
    Product product,
    TextEditingController quantityController,
    StateSetter setDialogState,
  ) {
    final newCostPriceController = TextEditingController();
    final newQuantityController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setInnerDialogState) {
            // Calculate values based on current input
            int? calculatedNewQuantity;
            int? calculatedAverageCostPrice;
            String errorMessage = '';

            if (newCostPriceController.text.isNotEmpty &&
                newQuantityController.text.isNotEmpty) {
              try {
                final newCostPrice = int.parse(newCostPriceController.text);
                final newQuantity = int.parse(newQuantityController.text);

                if (newQuantity <= 0) {
                  errorMessage = LocalizationService.getString('inventory_quantity_greater_zero');
                } else if (newCostPrice <= 0) {
                  errorMessage = LocalizationService.getString('inventory_cost_greater_zero');
                } else {
                  calculatedNewQuantity = product.stock + newQuantity;
                  final totalCostOld = product.costPrice * product.stock;
                  final totalCostNew = newCostPrice * newQuantity;
                  calculatedAverageCostPrice =
                      ((totalCostOld + totalCostNew) / calculatedNewQuantity)
                          .round();
                }
              } catch (e) {
                errorMessage = LocalizationService.getString('inventory_invalid_value');
              }
            }

            return AlertDialog(
              title: Text(LocalizationService.getString('inventory_import_different_price')),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Current cost price info
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            LocalizationService.getString('inventory_product_info'),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.black87,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                LocalizationService.getString('inventory_current_quantity'),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black87,
                                ),
                              ),
                              Text(
                                '${product.stock} ${product.unit}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                LocalizationService.getString('inventory_current_cost_price_label'),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black87,
                                ),
                              ),
                              Text(
                                CurrencyService.formatCurrency(product.costPrice),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // New cost price field
                    TextField(
                      controller: newCostPriceController,
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        setInnerDialogState(() {});
                      },
                      decoration: InputDecoration(
                        labelText: LocalizationService.getString('inventory_new_cost_price'),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.attach_money),
                        hintText: product.costPrice.toString(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // New quantity field
                    TextField(
                      controller: newQuantityController,
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        setInnerDialogState(() {});
                      },
                      decoration: InputDecoration(
                        labelText: LocalizationService.getString('inventory_new_quantity_needed'),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.inventory_2),
                        suffixText: product.unit,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Calculation info - Reactive
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: errorMessage.isNotEmpty
                            ? Colors.red[50]
                            : Colors.orange[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: errorMessage.isNotEmpty
                              ? Colors.red[200]!
                              : Colors.orange[200]!,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            LocalizationService.getString('inventory_calculation_label'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: errorMessage.isNotEmpty
                                  ? Colors.red[800]
                                  : Colors.orange[800],
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (errorMessage.isNotEmpty)
                            Text(
                              '⚠️ $errorMessage',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.red[700],
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          else
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // New quantity calculation
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        LocalizationService.getString('inventory_new_quantity'),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      Text(
                                        calculatedNewQuantity != null
                                            ? '$calculatedNewQuantity ${product.unit}'
                                            : '---',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // Average cost price calculation
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        LocalizationService.getString('inventory_average_cost_price'),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      Text(
                                        calculatedAverageCostPrice != null
                                            ? CurrencyService.formatCurrency(
                                                calculatedAverageCostPrice,
                                              )
                                            : '---',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.purple,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // Calculation breakdown
                                Text(
                                  LocalizationService.getString('inventory_calculation_formula').replaceAll('{old_cost}', product.costPrice.toString()).replaceAll('{old_quantity}', product.stock.toString()),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[600],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(LocalizationService.getString('btn_cancel')),
                ),
                ElevatedButton(
                  onPressed: errorMessage.isNotEmpty
                      ? null
                      : () async {
                          try {
                            if (newCostPriceController.text.isEmpty ||
                                newQuantityController.text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(LocalizationService.getString('product_fill_required_fields')),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            final newCostPrice =
                                int.parse(newCostPriceController.text);
                            final newQuantity =
                                int.parse(newQuantityController.text);

                            if (newQuantity <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(LocalizationService.getString('inventory_quantity_greater_zero')),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            if (newCostPrice <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(LocalizationService.getString('inventory_cost_greater_zero')),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            // Calculate new average cost price
                            final totalCostOld =
                                product.costPrice * product.stock;
                            final totalCostNew = newCostPrice * newQuantity;
                            final totalQuantity = product.stock + newQuantity;
                            final averageCostPrice =
                                ((totalCostOld + totalCostNew) / totalQuantity)
                                    .round();

                            // Update product
                            final updatedProduct = product.copyWith(
                              stock: totalQuantity,
                              costPrice: averageCostPrice,
                            );

                            await _productService.updateProduct(updatedProduct);

                            // Invalidate statistics cache when product stock is updated
                            StatisticsCacheService.invalidateCache();

                            if (!mounted) return;
                            Navigator.pop(context); // Close the inner dialog
                            Navigator.pop(context); // Close the main "Cập nhật kho" dialog

                            await _loadProducts();

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  LocalizationService.getString('inventory_update_success')
                                      .replaceAll('{name}', product.name)
                                      .replaceAll('{quantity}', newQuantity.toString())
                                      .replaceAll('{cost_price}', CurrencyService.formatCurrency(averageCostPrice)),
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${LocalizationService.getString('error')}: $e')),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: errorMessage.isNotEmpty
                        ? Colors.grey
                        : Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(LocalizationService.getString('btn_update')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddProductDialog(BuildContext context) {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final costPriceController = TextEditingController(text: '0');
    final quantityController = TextEditingController(text: '0');
    final unitController = TextEditingController(text: 'cái');
    String selectedCategory = 'Khác'; // Will be updated from default
    File? selectedImage;
    final ImagePicker _picker = ImagePicker();
    bool _categoryLoaded = false;

    // Load default category from settings
    ProductCategoryService.getDefaultCategory().then((defaultCategory) {
      // This will be used when the dialog is shown
    });

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Load default category when dialog is first built (only once)
            if (!_categoryLoaded) {
              ProductCategoryService.getDefaultCategory().then((defaultCategory) {
                if (defaultCategory.isNotEmpty && ProductCategoryService.categories.contains(defaultCategory)) {
                  setDialogState(() {
                    selectedCategory = defaultCategory;
                    _categoryLoaded = true;
                  });
                }
              });
            }
            
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 24,
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF1E1E1E)
                      : Colors.white,
                ),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.9,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header with gradient
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.purple[600]!, Colors.purple[400]!],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: const Icon(
                              Icons.add_circle_outline,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                LocalizationService.getString('product_add_new_title'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                LocalizationService.getString('product_add_inventory_subtitle'),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Content - scrollable
                    Expanded(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Image picker section
                              GestureDetector(
                                onTap: () async {
                                  // Check if permission is already granted
                                  bool hasPermission =
                                      await PermissionService.isPhotoLibraryPermissionGranted();

                                  // If not granted, request permission
                                  if (!hasPermission) {
                                    hasPermission =
                                        await PermissionService.requestPhotoLibraryPermission();

                                    // If still not granted after request, user denied it
                                    if (!hasPermission) {
                                      if (!mounted) return;
                                      showDialog(
                                        context: context,
                                        builder: (BuildContext ctx) {
                                          return AlertDialog(
                                            title: Text(
                                              LocalizationService.getString('permission_required_title'),
                                            ),
                                            content: Text(
                                              LocalizationService.getString('permission_gallery_message'),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx),
                                                child: Text(LocalizationService.getString('btn_cancel')),
                                              ),
                                              ElevatedButton(
                                                onPressed: () async {
                                                  Navigator.pop(ctx);
                                                  await PermissionService.openSettings();
                                                },
                                                child: Text(
                                                  LocalizationService.getString('btn_open_settings'),
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                      return;
                                    }
                                  }

                                  // Permission granted - open image picker
                                  final XFile? image = await _picker.pickImage(
                                    source: ImageSource.gallery,
                                  );
                                  if (image != null) {
                                    setDialogState(() {
                                      selectedImage = File(image.path);
                                    });
                                  }
                                },
                                child: Container(
                                  width: double.infinity,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.purple[200]!,
                                      width: 2,
                                    ),
                                  ),
                                  child: selectedImage != null
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: Image.file(
                                            selectedImage!,
                                            fit: BoxFit.cover,
                                          ),
                                        )
                                      : Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.image_outlined,
                                              size: 40,
                                              color: Colors.purple[300],
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              LocalizationService.getString('product_select_image'),
                                              style: TextStyle(
                                                color: Colors.purple[400],
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Name field
                              TextField(
                                controller: nameController,
                                decoration: InputDecoration(
                                  labelText: LocalizationService.getString('inventory_product_name'),
                                  labelStyle: TextStyle(
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.grey[300]
                                        : Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  floatingLabelBehavior: FloatingLabelBehavior.always,
                                  prefixIcon: const Icon(Icons.label_outline),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.grey[300]!,
                                      width: 1.5,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Colors.purple,
                                      width: 2,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Price field
                              TextField(
                                controller: priceController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: LocalizationService.getString('inventory_selling_price'),
                                  labelStyle: TextStyle(
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.grey[300]
                                        : Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  floatingLabelBehavior: FloatingLabelBehavior.always,
                                  prefixIcon: const Icon(Icons.attach_money),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.grey[300]!,
                                      width: 1.5,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Colors.purple,
                                      width: 2,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Cost price field
                              TextField(
                                controller: costPriceController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: LocalizationService.getString('inventory_cost_price'),
                                  labelStyle: TextStyle(
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.grey[300]
                                        : Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  prefixIcon: const Icon(Icons.shopping_bag),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.grey[300]!,
                                      width: 1.5,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Colors.purple,
                                      width: 2,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Quantity field
                              TextField(
                                controller: quantityController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: LocalizationService.getString('inventory_quantity_label'),
                                  labelStyle: TextStyle(
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.grey[300]
                                        : Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  prefixIcon: const Icon(Icons.inventory_2),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.grey[300]!,
                                      width: 1.5,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Colors.purple,
                                      width: 2,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Unit field
                              TextField(
                                controller: unitController,
                                decoration: InputDecoration(
                                  labelText: LocalizationService.getString('inventory_unit_hint'),
                                  labelStyle: TextStyle(
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.grey[300]
                                        : Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  prefixIcon: const Icon(Icons.straighten),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.grey[300]!,
                                      width: 1.5,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Colors.purple,
                                      width: 2,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Category dropdown
                              StatefulBuilder(
                                builder: (context, setDropdownState) {
                                  return InputDecorator(
                                    decoration: InputDecoration(
                                      labelText: LocalizationService.getString('inventory_category_placeholder'),
                                      labelStyle: TextStyle(
                                        color: Theme.of(context).brightness == Brightness.dark
                                            ? Colors.grey[300]
                                            : Colors.black,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      prefixIcon: const Icon(Icons.category),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.grey[300]!,
                                          width: 1.5,
                                        ),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                    ),
                                    child: DropdownButton<int>(
                                      value: ProductCategoryService.categories.indexOf(selectedCategory),
                                      isExpanded: true,
                                      underline: const SizedBox(),
                                      items: List.generate(ProductCategoryService.categoryDisplayNames.length, (index) {
                                        return DropdownMenuItem<int>(
                                          value: index,
                                          child: Text(ProductCategoryService.categoryDisplayNames[index]),
                                        );
                                      }),
                                      onChanged: (int? newIndex) {
                                        setDialogState(() {
                                          if (newIndex != null) {
                                            selectedCategory = ProductCategoryService.categories[newIndex];
                                          }
                                        });
                                      },
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Action buttons
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                side: BorderSide(
                                  color: Colors.grey[300]!,
                                  width: 1.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                LocalizationService.getString('btn_cancel'),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                try {
                                  if (nameController.text.isEmpty ||
                                      priceController.text.isEmpty ||
                                      costPriceController.text.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          LocalizationService.getString('product_fill_required_fields'),
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                    return;
                                  }

                                  final name = nameController.text;
                                  final price = int.parse(priceController.text);
                                  final costPrice = int.parse(
                                    costPriceController.text,
                                  );
                                  final quantity = int.parse(
                                    quantityController.text,
                                  );
                                  final unit = unitController.text.isEmpty
                                      ? 'cái'
                                      : unitController.text;

                                  // Save image if selected
                                  String? imagePath;
                                  if (selectedImage != null) {
                                    imagePath = await ImageService.saveProductImage(
                                      selectedImage!,
                                    );
                                  }

                                  // Add to database
                                  await _productService.addProduct(
                                    name,
                                    price,
                                    costPrice,
                                    category: selectedCategory,
                                    unit: unit,
                                    stock: quantity,
                                    imagePath: imagePath,
                                  );

                                  if (!mounted) return;
                                  Navigator.pop(context);

                                  // Reload products
                                  await _loadProducts();

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        LocalizationService.getString('product_add_success').replaceAll('{name}', name),
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('${LocalizationService.getString('error')}: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purple,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                LocalizationService.getString('btn_add'),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadProducts,
      child: Scaffold(
        body: Column(
          children: [
            // Summary card with gradient
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orangeAccent, Colors.white],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 0.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _activeFilter = _activeFilter == 'all'
                                    ? null
                                    : 'all';
                                _filterProducts();
                              });
                            },
                            child: _buildStatItem(
                              value: allProducts.length.toString(),
                              label: '${LocalizationService.getString('inventory_total')}\n',
                              color: Colors.blue,
                              icon: Icons.inventory_2,
                              isActive:
                                  _activeFilter == 'all' || _activeFilter == null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _activeFilter = _activeFilter == 'inStock'
                                    ? null
                                    : 'inStock';
                                _filterProducts();
                              });
                            },
                            child: _buildStatItem(
                              value: _getProductsInStock().toString(),
                              label: '${LocalizationService.getString('inventory_in_stock_label')}\n',
                              color: Colors.green,
                              icon: Icons.check_circle,
                              isActive: _activeFilter == 'inStock',
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _activeFilter = _activeFilter == 'lowStock'
                                    ? null
                                    : 'lowStock';
                                _filterProducts();
                              });
                            },
                            child: _buildStatItem(
                              value: _getLowStockProducts().toString(),
                              label: '${LocalizationService.getString('inventory_low_stock_label')}\n',
                              color: Colors.orange,
                              icon: Icons.warning,
                              isActive: _activeFilter == 'lowStock',
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _activeFilter = _activeFilter == 'outOfStock'
                                    ? null
                                    : 'outOfStock';
                                _filterProducts();
                              });
                            },
                            child: _buildStatItem(
                              value: _getProductsOutOfStock().toString(),
                              label: LocalizationService.getString('inventory_out_of_stock_label'),
                              color: Colors.red,
                              icon: Icons.cancel,
                              isActive: _activeFilter == 'outOfStock',
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _activeFilter = _activeFilter == 'value'
                                    ? null
                                    : 'value';
                                _filterProducts();
                              });
                            },
                            child: _buildStatItem(
                              value:
                                  '${(_getTotalInventoryValue() / 1000000).toStringAsFixed(1)} Tr',
                              label: LocalizationService.getString('inventory_total_value'),
                              color: Colors.purple,
                              icon: Icons.monetization_on,
                              isActive: false,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Search and Action Buttons
            Padding(
              padding: const EdgeInsets.all(1.5),
              child: Row(
                children: [
                  // Search TextField
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: LocalizationService.getString('inventory_search_placeholder'),
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Colors.grey,
                            width: 2,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Colors.blue,
                            width: 5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Add Product Button
                  ElevatedButton(
                    onPressed: () {
                      _showAddProductDialog(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50),
                      ),
                    ),
                    child: const Icon(Icons.add, size: 32),
                  ),
                  const SizedBox(width: 8),
                  // Delete Product Button
                  ElevatedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) {
                          String sortBy =
                              'name'; // 'name', 'quantity', 'price'
                          String searchQuery = '';
                          return StatefulBuilder(
                            builder: (context, setDialogState) {
                              // Sort products based on selected option
                              List<Product> sortedProducts = List.from(
                                allProducts,
                              );
                              
                              // Filter by search query
                              if (searchQuery.isNotEmpty) {
                                sortedProducts = sortedProducts.where((product) {
                                  return product.name.toLowerCase().contains(searchQuery) ||
                                      product.category.toLowerCase().contains(searchQuery);
                                }).toList();
                              }
                              
                              if (sortBy == 'name') {
                                sortedProducts.sort(
                                  (a, b) => a.name.compareTo(b.name),
                                );
                              } else if (sortBy == 'quantity') {
                                sortedProducts.sort(
                                  (a, b) => b.stock.compareTo(a.stock),
                                );
                              } else if (sortBy == 'price') {
                                sortedProducts.sort(
                                  (a, b) => b.price.compareTo(a.price),
                                );
                              }

                              return Dialog(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? const Color(0xFF1E1E1E)
                                        : Colors.white,
                                  ),
                                  child: Column(
                                    children: [
                                      // Header with gradient
                                      Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.red[600]!,
                                              Colors.red[400]!,
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(16),
                                            topRight: Radius.circular(16),
                                          ),
                                        ),
                                        padding: const EdgeInsets.all(20),
                                        child: Row(
                                          children: [
                                            Container(
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(
                                                  alpha: 0.3,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              padding: const EdgeInsets.all(12),
                                              child: const Icon(
                                                Icons.delete_outline,
                                                color: Colors.white,
                                                size: 28,
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  LocalizationService.getString('product_delete_confirm_title'),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 22,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  LocalizationService.getString('inventory_management_subtitle'),
                                                  style: TextStyle(
                                                    color: Colors.white
                                                        .withValues(alpha: 0.8),
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Search bar
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        child: TextField(
                                          onChanged: (value) {
                                            setDialogState(() {
                                              searchQuery = value.toLowerCase();
                                            });
                                          },
                                          decoration: InputDecoration(
                                            hintText: LocalizationService.getString('inventory_search_placeholder'),
                                            prefixIcon: const Icon(Icons.search),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                          ),
                                        ),
                                      ),
                                      // Sort buttons
                                      Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: ElevatedButton.icon(
                                                onPressed: () {
                                                  setDialogState(() {
                                                    sortBy = 'name';
                                                  });
                                                },
                                                icon: const Icon(
                                                  Icons.sort_by_alpha,
                                                  size: 16,
                                                ),
                                                label: Text(
                                                  LocalizationService.getString('inventory_sort_by_name'),
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      sortBy == 'name'
                                                      ? Colors.blue
                                                      : Colors.grey[200],
                                                  foregroundColor:
                                                      sortBy == 'name'
                                                      ? Colors.white
                                                      : Colors.black87,
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 10,
                                                      ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: ElevatedButton.icon(
                                                onPressed: () {
                                                  setDialogState(() {
                                                    sortBy = 'quantity';
                                                  });
                                                },
                                                icon: const Icon(
                                                  Icons.inventory,
                                                  size: 16,
                                                ),
                                                label: Text(
                                                  LocalizationService.getString('inventory_sort_by_quantity'),
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      sortBy == 'quantity'
                                                      ? Colors.blue
                                                      : Colors.grey[200],
                                                  foregroundColor:
                                                      sortBy == 'quantity'
                                                      ? Colors.white
                                                      : Colors.black87,
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 10,
                                                      ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: ElevatedButton.icon(
                                                onPressed: () {
                                                  setDialogState(() {
                                                    sortBy = 'price';
                                                  });
                                                },
                                                icon: const Icon(
                                                  Icons.attach_money,
                                                  size: 16,
                                                ),
                                                label: Text(
                                                  LocalizationService.getString('inventory_sort_by_price'),
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      sortBy == 'price'
                                                      ? Colors.blue
                                                      : Colors.grey[200],
                                                  foregroundColor:
                                                      sortBy == 'price'
                                                      ? Colors.white
                                                      : Colors.black87,
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 10,
                                                      ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Product list
                                      Expanded(
                                        child: ListView.separated(
                                          shrinkWrap: true,
                                          itemCount: sortedProducts.length,
                                          separatorBuilder: (context, index) =>
                                              Divider(
                                                height: 1,
                                                thickness: 1,
                                                indent: 16,
                                                endIndent: 16,
                                                color: Colors.grey[300],
                                              ),
                                          itemBuilder: (context, index) {
                                            final product =
                                                sortedProducts[index];
                                            return Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 12,
                                                  ),
                                              child: InkWell(
                                                onTap: () {
                                                  showDialog(
                                                    context: context,
                                                    builder: (context) {
                                                      return Dialog(
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                16,
                                                              ),
                                                        ),
                                                        child: Container(
                                                          decoration: BoxDecoration(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  16,
                                                                ),
                                                            color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.white,
                                                          ),
                                                          padding:
                                                              const EdgeInsets.all(
                                                                24,
                                                              ),
                                                          child: Column(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              // Warning icon
                                                              Container(
                                                                decoration: BoxDecoration(
                                                                  color: Colors
                                                                      .red[50],
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        50,
                                                                      ),
                                                                ),
                                                                padding:
                                                                    const EdgeInsets.all(
                                                                      16,
                                                                    ),
                                                                child: Icon(
                                                                  Icons
                                                                      .warning_rounded,
                                                                  size: 40,
                                                                  color: Colors
                                                                      .red[600],
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                height: 20,
                                                              ),
                                                              // Title
                                                              Text(
                                                                LocalizationService.getString('product_delete_confirm_title'),
                                                                style: const TextStyle(
                                                                  fontSize: 20,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                height: 12,
                                                              ),
                                                              // Product info card
                                                              Container(
                                                                decoration: BoxDecoration(
                                                                  color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2A2A2A) : Colors.blue[50],
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        12,
                                                                      ),
                                                                  border: Border.all(
                                                                    color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF3A3A3A) : Colors.blue[200]!,
                                                                    width: 1,
                                                                  ),
                                                                ),
                                                                padding:
                                                                    const EdgeInsets.all(
                                                                      16,
                                                                    ),
                                                                child: Column(
                                                                  crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .start,
                                                                  children: [
                                                                    // Product image if available
                                                                    if (product.imagePath != null && product.imagePath!.isNotEmpty)
                                                                      Center(
                                                                        child: Container(
                                                                          margin: const EdgeInsets.only(bottom: 16),
                                                                          decoration: BoxDecoration(
                                                                            borderRadius: BorderRadius.circular(8),
                                                                            border: Border.all(
                                                                              color: Colors.grey[300]!,
                                                                              width: 1,
                                                                            ),
                                                                          ),
                                                                          child: ClipRRect(
                                                                            borderRadius: BorderRadius.circular(8),
                                                                            child: Image.file(
                                                                              File(product.imagePath!),
                                                                              height: 120,
                                                                              width: 120,
                                                                              fit: BoxFit.cover,
                                                                              errorBuilder: (context, error, stackTrace) {
                                                                                return Container(
                                                                                  height: 120,
                                                                                  width: 120,
                                                                                  color: Colors.grey[200],
                                                                                  child: Icon(
                                                                                    Icons.image,
                                                                                    size: 40,
                                                                                    color: Colors.grey[400],
                                                                                  ),
                                                                                );
                                                                              },
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    Row(
                                                                      children: [
                                                                        Expanded(
                                                                          child: Column(
                                                                            crossAxisAlignment:
                                                                                CrossAxisAlignment.start,
                                                                            children: [
                                                                              Text(
                                                                                LocalizationService.getString('inventory_product_label_name'),
                                                                                style: TextStyle(
                                                                                  fontSize: 12,
                                                                                  color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[400] : Colors.grey[600],
                                                                                  fontWeight: FontWeight.w500,
                                                                                ),
                                                                              ),
                                                                              const SizedBox(
                                                                                height: 4,
                                                                              ),
                                                                              Text(
                                                                                product.name,
                                                                                style: TextStyle(
                                                                                  fontSize: 16,
                                                                                  fontWeight: FontWeight.bold,
                                                                                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                                                                                ),
                                                                                maxLines: 2,
                                                                                overflow: TextOverflow.ellipsis,
                                                                              ),
                                                                            ],
                                                                          ),
                                                                        ),
                                                                        Container(
                                                                          decoration: BoxDecoration(
                                                                            color:
                                                                                Colors.orange[100],
                                                                            borderRadius: BorderRadius.circular(
                                                                              8,
                                                                            ),
                                                                          ),
                                                                          padding: const EdgeInsets.symmetric(
                                                                            horizontal:
                                                                                12,
                                                                            vertical:
                                                                                8,
                                                                          ),
                                                                          child: Text(
                                                                            '${product.stock}',
                                                                            style: const TextStyle(
                                                                              fontSize: 18,
                                                                              fontWeight: FontWeight.bold,
                                                                              color: Colors.orange,
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                    const SizedBox(
                                                                      height:
                                                                          16,
                                                                    ),
                                                                    // Prices section
                                                                    Row(
                                                                      children: [
                                                                        Expanded(
                                                                          child: Column(
                                                                            crossAxisAlignment:
                                                                                CrossAxisAlignment.start,
                                                                            children: [
                                                                              Text(
                                                                                LocalizationService.getString('inventory_product_label_selling_price'),
                                                                                style: TextStyle(
                                                                                  fontSize: 12,
                                                                                  color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[400] : Colors.grey[600],
                                                                                  fontWeight: FontWeight.w500,
                                                                                ),
                                                                              ),
                                                                              const SizedBox(
                                                                                height: 4,
                                                                              ),
                                                                              Text(
                                                                                CurrencyService.formatCurrency(product.price),
                                                                                style: const TextStyle(
                                                                                  fontSize: 14,
                                                                                  fontWeight: FontWeight.bold,
                                                                                  color: Colors.green,
                                                                                ),
                                                                              ),
                                                                            ],
                                                                          ),
                                                                        ),
                                                                        Expanded(
                                                                          child: Column(
                                                                            crossAxisAlignment:
                                                                                CrossAxisAlignment.start,
                                                                            children: [
                                                                              Text(
                                                                                LocalizationService.getString('inventory_product_label_cost_price'),
                                                                                style: TextStyle(
                                                                                  fontSize: 12,
                                                                                  color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[400] : Colors.grey[600],
                                                                                  fontWeight: FontWeight.w500,
                                                                                ),
                                                                              ),
                                                                              const SizedBox(
                                                                                height: 4,
                                                                              ),
                                                                              Text(
                                                                                CurrencyService.formatCurrency(product.costPrice),
                                                                                style: const TextStyle(
                                                                                  fontSize: 14,
                                                                                  fontWeight: FontWeight.bold,
                                                                                  color: Colors.purple,
                                                                                ),
                                                                              ),
                                                                            ],
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                height: 20,
                                                              ),
                                                              // Warning text
                                                              RichText(
                                                                textAlign:
                                                                    TextAlign
                                                                        .center,
                                                                text: TextSpan(
                                                                  style: TextStyle(
                                                                    fontSize:
                                                                        14,
                                                                    color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[300] : Colors.grey[700],
                                                                  ),
                                                                  children: [
                                                                    TextSpan(
                                                                      text:
                                                                          LocalizationService.getString('product_delete_confirm_part1'),
                                                                    ),
                                                                    TextSpan(
                                                                      text:
                                                                          '\"${product.name}\"',
                                                                      style: const TextStyle(
                                                                        fontWeight:
                                                                            FontWeight.bold,
                                                                        color: Colors
                                                                            .red,
                                                                      ),
                                                                    ),
                                                                    TextSpan(
                                                                      text:
                                                                          LocalizationService.getString('product_delete_confirm_part2'),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                height: 24,
                                                              ),
                                                              // Action buttons
                                                              Row(
                                                                children: [
                                                                  Expanded(
                                                                    child: TextButton(
                                                                      onPressed: () =>
                                                                          Navigator.pop(
                                                                            context,
                                                                          ),
                                                                      style: TextButton.styleFrom(
                                                                        padding: const EdgeInsets.symmetric(
                                                                          vertical:
                                                                              12,
                                                                        ),
                                                                        shape: RoundedRectangleBorder(
                                                                          borderRadius:
                                                                              BorderRadius.circular(
                                                                                8,
                                                                              ),
                                                                          side: BorderSide(
                                                                            color:
                                                                                Theme.of(context).brightness == Brightness.dark ? Colors.grey[600]! : Colors.grey,
                                                                            width:
                                                                                1,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                      child: Text(
                                                                        LocalizationService.getString('btn_cancel'),
                                                                        style: TextStyle(
                                                                          fontSize:
                                                                              14,
                                                                          fontWeight:
                                                                              FontWeight.w600,
                                                                          color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[300] : Colors.grey,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  const SizedBox(
                                                                    width: 12,
                                                                  ),
                                                                  Expanded(
                                                                    child: ElevatedButton(
                                                                      onPressed: () async {
                                                                        try {
                                                                          final success = await _productService.hardDeleteProduct(
                                                                            product.id,
                                                                          );

                                                                          if (success) {
                                                                            final products =
                                                                                await _productService.getAllProducts();

                                                                            if (!mounted)
                                                                              return;

                                                                            setState(() {
                                                                              allProducts = products;
                                                                              _filterProducts();
                                                                            });

                                                                            if (!mounted)
                                                                              return;
                                                                            Navigator.pop(
                                                                              context,
                                                                            );
                                                                            Navigator.pop(
                                                                              context,
                                                                            );

                                                                            ScaffoldMessenger.of(
                                                                              context,
                                                                            ).showSnackBar(
                                                                              SnackBar(
                                                                                content: Text(
                                                                                  LocalizationService.getString('product_delete_success').replaceAll('{name}', product.name),
                                                                                ),
                                                                                backgroundColor: Colors.green,
                                                                              ),
                                                                            );
                                                                          } else {
                                                                            if (!mounted)
                                                                              return;
                                                                            Navigator.pop(
                                                                              context,
                                                                            );
                                                                            ScaffoldMessenger.of(
                                                                              context,
                                                                            ).showSnackBar(
                                                                              SnackBar(
                                                                                backgroundColor: Colors.red,
                                                                                content: Text(
                                                                                  LocalizationService.getString('product_delete_error'),
                                                                                ),
                                                                              ),
                                                                            );
                                                                          }
                                                                        } catch (
                                                                          e
                                                                        ) {
                                                                          if (!mounted)
                                                                            return;
                                                                          Navigator.pop(
                                                                            context,
                                                                          );
                                                                          ScaffoldMessenger.of(
                                                                            context,
                                                                          ).showSnackBar(
                                                                            SnackBar(
                                                                              backgroundColor: Colors.red,
                                                                              content: Text(
                                                                                '${LocalizationService.getString('error')}: $e',
                                                                              ),
                                                                            ),
                                                                          );
                                                                        }
                                                                      },
                                                                      style: ElevatedButton.styleFrom(
                                                                        backgroundColor:
                                                                            Colors.red,
                                                                        foregroundColor:
                                                                            Colors.white,
                                                                        padding: const EdgeInsets.symmetric(
                                                                          vertical:
                                                                              12,
                                                                        ),
                                                                        shape: RoundedRectangleBorder(
                                                                          borderRadius:
                                                                              BorderRadius.circular(
                                                                                8,
                                                                              ),
                                                                        ),
                                                                      ),
                                                                      child: Text(
                                                                        LocalizationService.getString('btn_delete'),
                                                                        style: const TextStyle(
                                                                          fontSize:
                                                                              14,
                                                                          fontWeight:
                                                                              FontWeight.bold,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  );
                                                },
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                    color: Colors.white,
                                                  ),
                                                  padding: const EdgeInsets.all(
                                                    12,
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      // Product number badge
                                                      Container(
                                                        width: 40,
                                                        height: 40,
                                                        decoration: BoxDecoration(
                                                          gradient: LinearGradient(
                                                            colors: [
                                                              Colors
                                                                  .orange[400]!,
                                                              Colors
                                                                  .orange[600]!,
                                                            ],
                                                            begin: Alignment
                                                                .topLeft,
                                                            end: Alignment
                                                                .bottomRight,
                                                          ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                50,
                                                              ),
                                                        ),
                                                        child: Center(
                                                          child: Text(
                                                            '${index + 1}',
                                                            style:
                                                                const TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize: 16,
                                                                ),
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      // Product info
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              product.name,
                                                              style: const TextStyle(
                                                                color: Colors.black54,
                                                                fontSize: 15,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                            ),
                                                            const SizedBox(
                                                              height: 4,
                                                            ),
                                                            Row(
                                                              children: [
                                                                Expanded(
                                                                  child: Text(
                                                                    '${LocalizationService.getString('inventory_product_label_selling_price')}: ${CurrencyService.formatCurrency(product.price)}',
                                                                    style: TextStyle(
                                                                      fontSize:
                                                                          12,
                                                                      color: Colors.green,
                                                                    ),
                                                                    maxLines: 1,
                                                                    overflow:
                                                                        TextOverflow
                                                                            .ellipsis,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                            const SizedBox(
                                                              height: 2,
                                                            ),
                                                            Text(
                                                              '${LocalizationService.getString('inventory_product_label_cost_price')}: ${CurrencyService.formatCurrency(product.costPrice)}',
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                color: Colors.purple,
                                                              ),
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      // Quantity info
                                                      Container(
                                                        decoration: BoxDecoration(
                                                          color:
                                                              Colors.blue[50],
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                8,
                                                              ),
                                                        ),
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 10,
                                                              vertical: 6,
                                                            ),
                                                        child: Column(
                                                          children: [
                                                            Text(
                                                              product.stock
                                                                  .toString(),
                                                              style: const TextStyle(
                                                                fontSize: 16,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color:
                                                                    Colors.blue,
                                                              ),
                                                            ),
                                                            Text(
                                                              product.unit,
                                                              style: TextStyle(
                                                                fontSize: 10,
                                                                color: Colors
                                                                    .grey[600],
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      // Delete button
                                                      Container(
                                                        decoration: BoxDecoration(
                                                          color: Colors.red[50],
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                8,
                                                              ),
                                                        ),
                                                        child: IconButton(
                                                          icon: Icon(
                                                            Icons
                                                                .delete_outline,
                                                            color:
                                                                Colors.red[600],
                                                            size: 20,
                                                          ),
                                                          onPressed: () {
                                                            showDialog(
                                                              context: context,
                                                              builder: (context) {
                                                                return Dialog(
                                                                  shape: RoundedRectangleBorder(
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                          16,
                                                                        ),
                                                                  ),
                                                                  child: Container(
                                                                    decoration: BoxDecoration(
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                            16,
                                                                          ),
                                                                      gradient: LinearGradient(
                                                                        colors: [
                                                                          Colors
                                                                              .white,
                                                                          Colors
                                                                              .grey[50]!,
                                                                        ],
                                                                        begin: Alignment
                                                                            .topCenter,
                                                                        end: Alignment
                                                                            .bottomCenter,
                                                                      ),
                                                                    ),
                                                                    padding:
                                                                        const EdgeInsets.all(
                                                                          24,
                                                                        ),
                                                                    child: Column(
                                                                      mainAxisSize:
                                                                          MainAxisSize
                                                                              .min,
                                                                      children: [
                                                                        // Warning icon
                                                                        Container(
                                                                          decoration: BoxDecoration(
                                                                            color:
                                                                                Colors.red[50],
                                                                            borderRadius: BorderRadius.circular(
                                                                              50,
                                                                            ),
                                                                          ),
                                                                          padding: const EdgeInsets.all(
                                                                            16,
                                                                          ),
                                                                          child: Icon(
                                                                            Icons.warning_rounded,
                                                                            size:
                                                                                40,
                                                                            color:
                                                                                Colors.red[600],
                                                                          ),
                                                                        ),
                                                                        const SizedBox(
                                                                          height:
                                                                              20,
                                                                        ),
                                                                        // Title
                                                                        Text(
                                                                          LocalizationService.getString('product_delete_confirm_title'),
                                                                          style: const TextStyle(
                                                                            fontSize:
                                                                                20,
                                                                            fontWeight:
                                                                                FontWeight.bold,
                                                                          ),
                                                                        ),
                                                                        const SizedBox(
                                                                          height:
                                                                              12,
                                                                        ),
                                                                        // Product info card
                                                                        Container(
                                                                          decoration: BoxDecoration(
                                                                            color:
                                                                                Colors.blue[50],
                                                                            borderRadius: BorderRadius.circular(
                                                                              12,
                                                                            ),
                                                                            border: Border.all(
                                                                              color: Colors.blue[200]!,
                                                                              width: 1,
                                                                            ),
                                                                          ),
                                                                          padding: const EdgeInsets.all(
                                                                            16,
                                                                          ),
                                                                          child: Column(
                                                                            crossAxisAlignment:
                                                                                CrossAxisAlignment.start,
                                                                            children: [
                                                                              Row(
                                                                                children: [
                                                                                  Expanded(
                                                                                    child: Column(
                                                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                                                      children: [
                                                                                        Text(
                                                                                          LocalizationService.getString('inventory_product_label_name'),
                                                                                          style: TextStyle(
                                                                                            fontSize: 12,
                                                                                            color: Colors.grey[600],
                                                                                            fontWeight: FontWeight.w500,
                                                                                          ),
                                                                                        ),
                                                                                        const SizedBox(
                                                                                          height: 4,
                                                                                        ),
                                                                                        Text(
                                                                                          product.name,
                                                                                          style: const TextStyle(
                                                                                            fontSize: 16,
                                                                                            fontWeight: FontWeight.bold,
                                                                                          ),
                                                                                          maxLines: 2,
                                                                                          overflow: TextOverflow.ellipsis,
                                                                                        ),
                                                                                      ],
                                                                                    ),
                                                                                  ),
                                                                                  Container(
                                                                                    decoration: BoxDecoration(
                                                                                      color: Colors.orange[100],
                                                                                      borderRadius: BorderRadius.circular(
                                                                                        8,
                                                                                      ),
                                                                                    ),
                                                                                    padding: const EdgeInsets.symmetric(
                                                                                      horizontal: 12,
                                                                                      vertical: 8,
                                                                                    ),
                                                                                    child: Text(
                                                                                      '${product.stock}',
                                                                                      style: const TextStyle(
                                                                                        fontSize: 18,
                                                                                        fontWeight: FontWeight.bold,
                                                                                        color: Colors.orange,
                                                                                      ),
                                                                                    ),
                                                                                  ),
                                                                                ],
                                                                              ),
                                                                              const SizedBox(
                                                                                height: 16,
                                                                              ),
                                                                              // Prices section
                                                                              Row(
                                                                                children: [
                                                                                  Expanded(
                                                                                    child: Column(
                                                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                                                      children: [
                                                                                        Text(
                                                                                          LocalizationService.getString('inventory_product_label_selling_price'),
                                                                                          style: TextStyle(
                                                                                            fontSize: 12,
                                                                                            color: Colors.grey[600],
                                                                                            fontWeight: FontWeight.w500,
                                                                                          ),
                                                                                        ),
                                                                                        const SizedBox(
                                                                                          height: 4,
                                                                                        ),
                                                                                        Text(
                                                                                          CurrencyService.formatCurrency(product.price),
                                                                                          style: const TextStyle(
                                                                                            fontSize: 14,
                                                                                            fontWeight: FontWeight.bold,
                                                                                            color: Colors.green,
                                                                                          ),
                                                                                        ),
                                                                                      ],
                                                                                    ),
                                                                                  ),
                                                                                  Expanded(
                                                                                    child: Column(
                                                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                                                      children: [
                                                                                        Text(
                                                                                          LocalizationService.getString('inventory_product_label_cost_price'),
                                                                                          style: TextStyle(
                                                                                            fontSize: 12,
                                                                                            color: Colors.grey[600],
                                                                                            fontWeight: FontWeight.w500,
                                                                                          ),
                                                                                        ),
                                                                                        const SizedBox(
                                                                                          height: 4,
                                                                                        ),
                                                                                        Text(
                                                                                          CurrencyService.formatCurrency(product.costPrice),
                                                                                          style: const TextStyle(
                                                                                            fontSize: 14,
                                                                                            fontWeight: FontWeight.bold,
                                                                                            color: Colors.purple,
                                                                                          ),
                                                                                        ),
                                                                                      ],
                                                                                    ),
                                                                                  ),
                                                                                ],
                                                                              ),
                                                                            ],
                                                                          ),
                                                                        ),
                                                                        const SizedBox(
                                                                          height:
                                                                              20,
                                                                        ),
                                                                        // Warning text
                                                                        RichText(
                                                                          textAlign:
                                                                              TextAlign.center,
                                                                          text: TextSpan(
                                                                            style: TextStyle(
                                                                              fontSize: 14,
                                                                              color: Colors.grey[700],
                                                                            ),
                                                                            children: [
                                                                              TextSpan(
                                                                                text: LocalizationService.getString('product_delete_confirm_part1'),
                                                                              ),
                                                                              TextSpan(
                                                                                text: '\"${product.name}\"',
                                                                                style: const TextStyle(
                                                                                  fontWeight: FontWeight.bold,
                                                                                  color: Colors.red,
                                                                                ),
                                                                              ),
                                                                              TextSpan(
                                                                                text: LocalizationService.getString('product_delete_confirm_part2'),
                                                                              ),
                                                                            ],
                                                                          ),
                                                                        ),
                                                                        const SizedBox(
                                                                          height:
                                                                              24,
                                                                        ),
                                                                        // Action buttons
                                                                        Row(
                                                                          children: [
                                                                            Expanded(
                                                                              child: TextButton(
                                                                                onPressed: () => Navigator.pop(
                                                                                  context,
                                                                                ),
                                                                                style: TextButton.styleFrom(
                                                                                  padding: const EdgeInsets.symmetric(
                                                                                    vertical: 12,
                                                                                  ),
                                                                                  shape: RoundedRectangleBorder(
                                                                                    borderRadius: BorderRadius.circular(
                                                                                      8,
                                                                                    ),
                                                                                    side: const BorderSide(
                                                                                      color: Colors.grey,
                                                                                      width: 1,
                                                                                    ),
                                                                                  ),
                                                                                ),
                                                                                child: Text(
                                                                                  LocalizationService.getString('btn_cancel'),
                                                                                  style: const TextStyle(
                                                                                    fontSize: 14,
                                                                                    fontWeight: FontWeight.w600,
                                                                                    color: Colors.grey,
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                            ),
                                                                            const SizedBox(
                                                                              width: 12,
                                                                            ),
                                                                            Expanded(
                                                                              child: ElevatedButton(
                                                                                onPressed: () async {
                                                                                  try {
                                                                                    final success = await _productService.hardDeleteProduct(
                                                                                      product.id,
                                                                                    );

                                                                                    if (success) {
                                                                                      final products = await _productService.getAllProducts();

                                                                                      if (!mounted) return;

                                                                                      setState(
                                                                                        () {
                                                                                          allProducts = products;
                                                                                          _filterProducts();
                                                                                        },
                                                                                      );

                                                                                      if (!mounted) return;
                                                                                      Navigator.pop(
                                                                                        context,
                                                                                      );
                                                                                      Navigator.pop(
                                                                                        context,
                                                                                      );

                                                                                      ScaffoldMessenger.of(
                                                                                        context,
                                                                                      ).showSnackBar(
                                                                                        SnackBar(
                                                                                          content: Text(
                                                                                            LocalizationService.getString('product_delete_success').replaceAll('{name}', product.name),
                                                                                          ),
                                                                                          backgroundColor: Colors.green,
                                                                                        ),
                                                                                      );
                                                                                    } else {
                                                                                      if (!mounted) return;
                                                                                      Navigator.pop(
                                                                                        context,
                                                                                      );
                                                                                      ScaffoldMessenger.of(
                                                                                        context,
                                                                                      ).showSnackBar(
                                                                                        SnackBar(
                                                                                          backgroundColor: Colors.red,
                                                                                          content: Text(
                                                                                            LocalizationService.getString('product_delete_error'),
                                                                                          ),
                                                                                        ),
                                                                                      );
                                                                                    }
                                                                                  } catch (
                                                                                    e
                                                                                  ) {
                                                                                    if (!mounted) return;
                                                                                    Navigator.pop(
                                                                                      context,
                                                                                    );
                                                                                    ScaffoldMessenger.of(
                                                                                      context,
                                                                                    ).showSnackBar(
                                                                                      SnackBar(
                                                                                        backgroundColor: Colors.red,
                                                                                        content: Text(
                                                                                          '${LocalizationService.getString('error')}: $e',
                                                                                        ),
                                                                                      ),
                                                                                    );
                                                                                  }
                                                                                },
                                                                                style: ElevatedButton.styleFrom(
                                                                                  backgroundColor: Colors.red,
                                                                                  foregroundColor: Colors.white,
                                                                                  padding: const EdgeInsets.symmetric(
                                                                                    vertical: 12,
                                                                                  ),
                                                                                  shape: RoundedRectangleBorder(
                                                                                    borderRadius: BorderRadius.circular(
                                                                                      8,
                                                                                    ),
                                                                                  ),
                                                                                ),
                                                                                child: Text(
                                                                                  LocalizationService.getString('btn_delete'),
                                                                                  style: const TextStyle(
                                                                                    fontSize: 14,
                                                                                    fontWeight: FontWeight.bold,
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                            ),
                                                                          ],
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                );
                                                              },
                                                            );
                                                          },
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50),
                      ),
                    ),
                    child: const Icon(Icons.delete, size: 32),
                  ),
                ],
              ),
            ),

            // Sort Buttons
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 6.0,
              ),
              child: Row(
                children: [
                  // Name Sort Button
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            if (_sortBy == 'name') {
                              _sortAscending = !_sortAscending;
                            } else {
                              _sortBy = 'name';
                              _sortAscending = true;
                            }
                            _filterProducts();
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _sortBy == 'name'
                                ? Colors.orange.withValues(alpha: 0.15)
                                : Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _sortBy == 'name'
                                  ? Colors.orange
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                LocalizationService.getString('inventory_sort_by_name'),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: _sortBy == 'name'
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: _sortBy == 'name'
                                      ? Colors.orange
                                      : Colors.black87,
                                ),
                              ),
                              if (_sortBy == 'name')
                                Padding(
                                  padding: const EdgeInsets.only(left: 4.0),
                                  child: Icon(
                                    _sortAscending
                                        ? Icons.arrow_upward
                                        : Icons.arrow_downward,
                                    size: 14,
                                    color: Colors.orange,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Quantity Sort Button
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            if (_sortBy == 'quantity') {
                              _sortAscending = !_sortAscending;
                            } else {
                              _sortBy = 'quantity';
                              _sortAscending = true;
                            }
                            _filterProducts();
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _sortBy == 'quantity'
                                ? Colors.blue.withValues(alpha: 0.15)
                                : Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _sortBy == 'quantity'
                                  ? Colors.blue
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                LocalizationService.getString('inventory_sort_by_quantity'),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: _sortBy == 'quantity'
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: _sortBy == 'quantity'
                                      ? Colors.blue
                                      : Colors.black87,
                                ),
                              ),
                              if (_sortBy == 'quantity')
                                Padding(
                                  padding: const EdgeInsets.only(left: 4.0),
                                  child: Icon(
                                    _sortAscending
                                        ? Icons.arrow_upward
                                        : Icons.arrow_downward,
                                    size: 14,
                                    color: Colors.blue,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Category Dropdown
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: _selectedCategory != null && _selectedCategory != LocalizationService.getString('category_all')
                            ? Colors.purple.withValues(alpha: 0.15)
                            : Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF2A2A2A)
                                : Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _selectedCategory != null && _selectedCategory != LocalizationService.getString('category_all')
                              ? Colors.purple
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      height: 44,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: DropdownButton<String>(
                            value: _selectedCategory ?? LocalizationService.getString('inventory_all_categories'),
                            isExpanded: true,
                            underline: const SizedBox.shrink(),
                            isDense: true,
                            icon: Icon(
                              Icons.arrow_drop_down,
                              color: _selectedCategory != null && _selectedCategory != LocalizationService.getString('inventory_all_categories')
                                  ? Colors.purple
                                  : Theme.of(context).brightness == Brightness.dark
                                      ? Colors.grey[300]
                                      : Colors.black87,
                              size: 20,
                            ),
                            items: _getUniqueCategories().map((String category) {
                              return DropdownMenuItem<String>(
                                value: category,
                                alignment: AlignmentDirectional.center,
                                child: Text(
                                  category,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: _selectedCategory == category
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: _selectedCategory == category
                                        ? Colors.purple
                                        : Theme.of(context).brightness == Brightness.dark
                                            ? Colors.white
                                            : Colors.black87,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                _selectedCategory = newValue == LocalizationService.getString('inventory_all_categories') ? null : newValue;
                                _filterProducts();
                              });
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Product list
            Expanded(
              child: filteredProducts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          Text(
                            _searchController.text.isEmpty
                                ? LocalizationService.getString('product_no_products')
                                : LocalizationService.getString('product_no_results'),
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ResponsiveBuilder(
                      builder: (context, sizingInformation) {
                        final isMobile = sizingInformation.isMobile;

                        // Mobile: ListView with horizontal row layout
                        if (isMobile) {
                          return RepaintBoundary(
                            child: ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: filteredProducts.length,
                              itemBuilder: (context, index) {
                              final product = filteredProducts[index];
                              final stockColor = _getStockIndicatorColor(product.stock);
                              final stockStatus = _getStockStatus(product.stock);

                              return Card(
                                elevation: 4,
                                margin: const EdgeInsets.only(bottom: 12),
                                child: InkWell(
                                  onTap: () => _showAdjustStockDialog(product),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        // Product image or placeholder
                                        Container(
                                          width: 70,
                                          height: 70,
                                          decoration: BoxDecoration(
                                            color: Colors.grey[200],
                                            borderRadius: BorderRadius.circular(8),
                                            image: product.imagePath != null
                                                ? DecorationImage(
                                                    image: FileImage(
                                                      File(product.imagePath!),
                                                    ),
                                                    fit: BoxFit.cover,
                                                  )
                                                : null,
                                          ),
                                          child: product.imagePath == null
                                              ? const Icon(
                                                  Icons.image,
                                                  color: Colors.grey,
                                                )
                                              : null,
                                        ),
                                        const SizedBox(width: 12),

                                        // Product info
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                product.name,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      '${LocalizationService.getString('inventory_product_label_selling_price')}: ${CurrencyService.formatCurrency(product.price)}',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        color: Theme.of(context).brightness == Brightness.dark
                                                            ? Colors.white
                                                            : Colors.black,
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: Text(
                                                      ' ${LocalizationService.getString('inventory_product_label_cost_price')}: ${CurrencyService.formatCurrency(product.costPrice)}',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        color: Theme.of(context).brightness == Brightness.dark
                                                            ? Colors.white
                                                            : Colors.black,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: stockColor.withValues(alpha: 0.2),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      stockStatus,
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: stockColor,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Quantity display
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              product.stock.toString(),
                                              style: const TextStyle(
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blue,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              product.unit,
                                              style: TextStyle(
                                                fontSize: 20,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                            ),
                          );
                        }

                        // Tablet and Desktop: GridView with 2 columns
                        return RepaintBoundary(
                          child: GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 400,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                          itemCount: filteredProducts.length,
                          itemBuilder: (context, index) {
                            final product = filteredProducts[index];
                            final stockColor = _getStockIndicatorColor(product.stock);
                            final stockStatus = _getStockStatus(product.stock);

                            return Card(
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: InkWell(
                                onTap: () => _showAdjustStockDialog(product),
                                borderRadius: BorderRadius.circular(12),
                                child: SingleChildScrollView(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Product image
                                        Container(
                                          height: 120,
                                          width: double.infinity,
                                          decoration: BoxDecoration(
                                            color: Colors.grey[200],
                                            borderRadius: BorderRadius.circular(12),
                                            image: product.imagePath != null
                                                ? DecorationImage(
                                                    image: FileImage(
                                                      File(product.imagePath!),
                                                    ),
                                                    fit: BoxFit.cover,
                                                  )
                                                : null,
                                          ),
                                          child: product.imagePath == null
                                              ? const Icon(
                                                  Icons.image,
                                                  color: Colors.grey,
                                                  size: 48,
                                                )
                                              : null,
                                        ),
                                        const SizedBox(height: 12),

                                        // Product name
                                        Text(
                                          product.name,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 8),

                                        // Stock quantity display
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              product.stock.toString(),
                                              style: const TextStyle(
                                                fontSize: 28,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blue,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                product.unit,
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  color: Colors.grey[600],
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),

                                        // Stock status badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: stockColor.withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            stockStatus,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: stockColor,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                        const SizedBox(height: 8),

                                        // Price information
                                        Column(
                                          children: [
                                            Text(
                                              '${LocalizationService.getString('inventory_product_label_selling_price')}: ${CurrencyService.formatCurrency(product.price)}',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                color: Colors.green,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              textAlign: TextAlign.center,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${LocalizationService.getString('inventory_product_label_cost_price')}: ${CurrencyService.formatCurrency(product.costPrice)}',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.purple[600],
                                                fontWeight: FontWeight.w500,
                                              ),
                                              textAlign: TextAlign.center,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required String value,
    required String label,
    required Color color,
    required IconData icon,
    bool isActive = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 1,
      ),
      decoration: BoxDecoration(
        color: isActive ? color.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? color : Colors.transparent,
          width: isActive ? 2.5 : 0,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isActive ? color : Colors.grey[700],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
