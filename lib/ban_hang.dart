import 'package:flutter/material.dart';
import 'dart:io';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:responsive_builder/responsive_builder.dart';
import 'package:flutter/foundation.dart';
import 'models/product_model.dart';
import 'models/sold_item_model.dart';
import 'services/product_service.dart';
import 'services/notification_service.dart';
import 'services/currency_service.dart';
import 'services/firebase_service.dart';
import 'services/localization_service.dart';
import 'services/statistics_cache_service.dart';
import 'scripts/generate_test_data.dart';
import 'quan_ly_san_pham.dart';

class SalesPage extends StatefulWidget {
  final bool soundEnabled;
  final int lowStockThreshold;
  final bool notificationsEnabled;
  final ProductService? productService;

  const SalesPage({
    super.key,
    this.soundEnabled = true,
    this.lowStockThreshold = 5,
    this.notificationsEnabled = false,
    this.productService,
  });

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  final TextEditingController searchController = TextEditingController();
  final ScrollController soldItemsScrollController = ScrollController();
  bool _showSoldItems = false;

  late final ProductService _productService;
  AudioPlayer? _audioPlayer;
  bool _audioPlayerInitialized = false;

  late List<Product> allProducts;
  late List<Product> filteredProducts;
  late List<SoldItem> soldItems;

  final Map<int, int> quantities = {};
  String _sortBy = 'name'; // 'bestselling', 'name', 'price'
  bool _sortAscending = true; // true = ascending, false = descending
  int _layoutMode = 0; // 0 = list view, 1 = 2-column grid, 2 = simple grid (name + image only)
  
  // Cache for extracted image colors
  final Map<int, List<Color>> _productColorCache = {};

  @override
  void initState() {
    super.initState();
    // Log screen view to Analytics
    FirebaseService.logScreenView('Sales Page');
    // Use injected service or create default
    _productService = widget.productService ?? ProductService();
    allProducts = [];
    filteredProducts = [];
    soldItems = [];
    _initializeData();
    searchController.addListener(_filterProducts);
    _initializeAudioPlayer();
  }

  Future<void> _initializeAudioPlayer() async {
    // Skip audio specific initialization on Windows if just_audio is not supported or creates issues
    if (kIsWeb || Platform.isWindows || Platform.isLinux) {
      if (kDebugMode) print('Audio player not fully supported on this platform - skipping initialization');
      _audioPlayerInitialized = false;
      return;
    }
    
    try {
      _audioPlayer = AudioPlayer();
      _audioPlayerInitialized = true;
      if (kDebugMode) print('Audio player initialized successfully');
    } catch (e) {
      if (kDebugMode) print('Failed to create AudioPlayer instance: $e');
      _audioPlayerInitialized = false;
    }
  }



  /// Check if a product has duplicates with the same name and price
  bool _hasDuplicatesWithSamePricing(Product product, List<Product> productList) {
    return productList.where((p) => 
      p.name == product.name && 
      p.price == product.price && 
      p.id != product.id
    ).isNotEmpty;
  }

  /// Extract colors from product image or use default gradient
  /// DISABLED for performance - use default colors instead
  Future<List<Color>> _extractColorsFromImage(Product product) async {
    // Check cache first
    if (_productColorCache.containsKey(product.id)) {
      return _productColorCache[product.id]!;
    }

    // Return default colors immediately without processing images
    // Image processing is too slow on mobile devices
    final colors = [Colors.white, Color.fromARGB(255, 233, 240, 234)];
    _productColorCache[product.id] = colors;
    return colors;
    
    /* DISABLED - Too slow on real devices
    // If product has an image, extract colors
    if (product.imagePath != null && product.imagePath!.isNotEmpty) {
      try {
        final imageFile = File(product.imagePath!);
        if (await imageFile.exists()) {
          final paletteGenerator = await PaletteGenerator.fromImageProvider(
            FileImage(imageFile),
            size: const Size(100, 100), // Small size for faster processing
          );

          // Get dominant colors
          Color primaryColor = paletteGenerator.dominantColor?.color ?? 
                               paletteGenerator.vibrantColor?.color ?? 
                               Colors.blue[200]!;
          
          Color secondaryColor = paletteGenerator.lightVibrantColor?.color ?? 
                                 paletteGenerator.mutedColor?.color ?? 
                                 Colors.blue[100]!;

          // Make colors lighter for better readability
          primaryColor = _lightenColor(primaryColor, 0.7);
          secondaryColor = _lightenColor(secondaryColor, 0.8);

          final colors = [secondaryColor, primaryColor];
          _productColorCache[product.id] = colors;
          return colors;
        }
      } catch (e) {
        print('Error extracting colors from image: $e');
      }
    }

    // Fallback to grey color
    final colors = [Colors.white, Color.fromARGB(255, 233, 240, 234)];
    _productColorCache[product.id] = colors;
    return colors;
    */
  }


  /// Initialize data from database
  Future<void> _initializeData() async {
    try {
      // Load all products from database
      final products = await _productService.getAllProducts();

      // Load today's sold items from database
      final sold = await _productService.getTodaySoldItems();

      // Check if widget is still mounted before updating UI
      if (!mounted) return;

      setState(() {
        allProducts = products;
        soldItems = sold;

        // Initialize quantities
        for (var product in allProducts) {
          quantities[product.id] = 1;
        }
      });
      
      // Apply default sorting by name
      _filterProducts();
      
      // Don't pre-extract colors - it causes slowdown
      // Colors will be extracted lazily on first view if needed
    } catch (e) {
      // Check if widget is still mounted before showing error
      if (!mounted) return;

      print('Error initializing data: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
    }
  }

  void _filterProducts() {
    final query = searchController.text.toLowerCase();
    List<Product> filtered = allProducts
        .where((product) => product.name.toLowerCase().contains(query))
        .toList();
    
    // Apply sorting
    if (_sortBy == 'bestselling') {
      // Pre-calculate sales counts to avoid repeated where() calls
      final Map<int, int> salesCounts = {};
      for (var item in soldItems) {
        salesCounts[item.productId] = (salesCounts[item.productId] ?? 0) + item.quantity;
      }
      
      // Sort by number of sales today
      filtered.sort((a, b) {
        final aSalesCount = salesCounts[a.id] ?? 0;
        final bSalesCount = salesCounts[b.id] ?? 0;
        return bSalesCount.compareTo(aSalesCount); // Descending (highest sales first)
      });
    } else if (_sortBy == 'name') {
      filtered.sort((a, b) => a.name.compareTo(b.name));
      if (!_sortAscending) {
        filtered = filtered.reversed.toList();
      }
    } else if (_sortBy == 'price') {
      filtered.sort((a, b) => a.price.compareTo(b.price));
      if (!_sortAscending) {
        filtered = filtered.reversed.toList();
      }
    }
    
    setState(() {
      filteredProducts = filtered;
    });
  }

  void incrementQuantity(int productId) {
    setState(() {
      quantities[productId] = (quantities[productId] ?? 1) + 1;
    });
  }

  void decrementQuantity(int productId) {
    setState(() {
      if ((quantities[productId] ?? 1) > 1) {
        quantities[productId] = quantities[productId]! - 1;
      }
    });
  }

  Future<void> _checkAndNotifyLowStock(Product product) async {
    try {
      // Read notification setting from SharedPreferences to always get latest value
      final prefs = await SharedPreferences.getInstance();
      final notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;
      
      // Only show notification if notifications are enabled and stock is at or below threshold
      if (notificationsEnabled && product.stock > 0 && product.stock <= widget.lowStockThreshold) {
        final NotificationService notificationService = NotificationService();
        await notificationService.showWarning(
          'Sắp hết hàng',
          '${product.name} chỉ còn ${product.stock} ${product.unit}',
        );
        print('Low stock notification sent for: ${product.name}, stock: ${product.stock}');
      } else if (!notificationsEnabled) {
        print('Notifications disabled - skipping low stock notification for: ${product.name}');
      }
    } catch (e) {
      print('Error showing low stock notification: $e');
    }
  }

  void addToSoldItems(Product product, int quantity) async {
    try {
      final totalPrice = product.price * quantity;
      final newStock = product.stock - quantity;

      // Run database operations in parallel for speed
      final Future<bool> addSoldItemFuture = _productService.addSoldItem(
        productId: product.id,
        quantity: quantity,
        totalPrice: totalPrice,
      );

      final Future<void> updateStockFuture = newStock >= 0
          ? _productService.updateProduct(product.copyWith(stock: newStock))
          : Future.value();

      // Wait for both operations to complete
      final success = await addSoldItemFuture;
      await updateStockFuture;

      if (success) {
        // Invalidate statistics cache when a sale is made
        StatisticsCacheService.invalidateCache();

        // Update the product in allProducts list to keep data in sync
        final productIndex = allProducts.indexWhere((p) => p.id == product.id);
        if (productIndex != -1) {
          final updatedProduct = product.copyWith(stock: newStock);
          setState(() {
            allProducts[productIndex] = updatedProduct;
            // Re-filter to update filteredProducts if needed
            _filterProducts();
          });
        }

        // Play sound without waiting (fire and forget)
        if (_audioPlayerInitialized && widget.soundEnabled && _audioPlayer != null) {
          _audioPlayer!.setAsset('assets/sounds/Kaching.mp3').then((_) {
            _audioPlayer!.play().catchError((e) => print('Audio error: $e'));
          }).catchError((e) {
            print('Audio setup error: $e');
          });
        }

        // Reset quantity immediately
        quantities[product.id] = 1;

        // Check if widget is still mounted before showing snackbar
        if (!mounted) return;

        // Show snackbar immediately without waiting
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${product.name} x$quantity ${LocalizationService.getString('sales_sold')}'),
            duration: const Duration(milliseconds: 500),
            backgroundColor: Colors.green,
          ),
        );

        // Load sold items in background without blocking UI
        _loadTodaySoldItems();

        // Check and send low stock notification in background
        if (newStock >= 0) {
          _checkAndNotifyLowStock(product.copyWith(stock: newStock)).catchError((e) {
            print('Error in low stock notification: $e');
          });
        }
      }
    } catch (e) {
      if (!mounted) return;

      print('Error adding sold item: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _loadTodaySoldItems() async {
    try {
      final items = await _productService.getTodaySoldItems();
      setState(() {
        soldItems = items;
      });
    } catch (e) {
      print('Error loading sold items: $e');
    }
  }

  void removeSoldItem(int soldItemId) async {
    try {
      // Delete from database
      final success = await _productService.deleteSoldItem(soldItemId);

      if (success) {
        // Invalidate statistics cache when a sale is deleted
        StatisticsCacheService.invalidateCache();

        // Reload sold items from database
        await _loadTodaySoldItems();
      }
    } catch (e) {
      if (!mounted) return;

      print('Error removing sold item: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  /// Build list layout (current layout with quantity controls) - Responsive
  Widget _buildListLayout() {
    return ResponsiveBuilder(
      builder: (context, sizingInformation) {
        final isMobile = sizingInformation.isMobile;
        final isTablet = sizingInformation.isTablet;
        
        return RepaintBoundary(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 100),
            itemCount: filteredProducts.length,
            itemBuilder: (context, index) {
              final product = filteredProducts[index];
              final quantity = quantities[product.id] ?? 1;
            
            if (!_productColorCache.containsKey(product.id)) {
              _extractColorsFromImage(product);
            }
            
            return Card(
              margin: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : (isTablet ? 16 : 20),
                vertical: 4,
              ),
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: isMobile
                  ? Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? const Color.fromARGB(116, 20, 5, 5)
                                  : const Color.fromARGB(255, 250, 247, 153),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => addToSoldItems(product, quantity),
                                borderRadius: BorderRadius.circular(20),
                                splashColor: Colors.white.withValues(alpha: 0.3),
                                highlightColor: Colors.white.withValues(alpha: 0.1),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 15),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              product.name,
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Theme.of(context).brightness == Brightness.dark
                                                    ? Colors.white
                                                    : Colors.black,
                                              ),
                                            ),
                                            Text(
                                              CurrencyService.formatCurrency(product.price),
                                              style: const TextStyle(
                                                fontSize: 14,
                                                color: Colors.green,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            if (_hasDuplicatesWithSamePricing(product, filteredProducts))
                                              Padding(
                                                padding: const EdgeInsets.only(top: 4),
                                                child: Text(
                                                  'Giá vốn: ${CurrencyService.formatCurrency(product.costPrice)}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.purple[600],
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        width: 60,
                                        height: 60,
                                        margin: const EdgeInsets.only(left: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[300],
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: product.imagePath != null && product.imagePath!.isNotEmpty
                                              ? Image.file(
                                                  File(product.imagePath!),
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error, stackTrace) =>
                                                      const Icon(Icons.image, size: 30, color: Colors.grey),
                                                )
                                              : const Icon(Icons.image, size: 30, color: Colors.grey),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(1),
                          child: Column(
                            children: [
                              Text(LocalizationService.getString('sales_quantity_sold'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    onPressed: () => decrementQuantity(product.id),
                                    icon: const Icon(Icons.remove),
                                    iconSize: 16,
                                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                    padding: EdgeInsets.zero,
                                    style: IconButton.styleFrom(
                                      side: const BorderSide(color: Colors.grey),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      final controller = TextEditingController(text: quantity.toString());
                                      showDialog(
                                        context: context,
                                        builder: (BuildContext context) {
                                          return AlertDialog(
                                            title: Text(LocalizationService.getString('sales_enter_quantity')),
                                            content: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                FutureBuilder<Product?>(
                                                  future: _productService.getProductById(product.id),
                                                  builder: (context, snapshot) {
                                                    final currentProduct = snapshot.data ?? product;
                                                    return Text(
                                                      '${LocalizationService.getString('sales_in_stock')}: ${currentProduct.stock} ${currentProduct.unit}',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        color: Theme.of(context).brightness == Brightness.dark
                                                          ? Colors.white
                                                          : Colors.black,
                                                      ),
                                                    );
                                                  },
                                                ),
                                                const SizedBox(height: 12),
                                                TextField(
                                                  controller: controller,
                                                  keyboardType: TextInputType.number,
                                                  autofocus: true,
                                                  decoration: InputDecoration(
                                                    labelText: LocalizationService.getString('sales_quantity_want_to_sell'),
                                                    border: const OutlineInputBorder(),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(context),
                                                child: Text(LocalizationService.getString('btn_cancel')),
                                              ),
                                              ElevatedButton(
                                                onPressed: () {
                                                  final newQuantity = int.tryParse(controller.text);
                                                  if (newQuantity != null && newQuantity > 0) {
                                                    setState(() => quantities[product.id] = newQuantity);
                                                    Navigator.pop(context);
                                                  } else {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(content: Text(LocalizationService.getString('sales_invalid_quantity'))),
                                                    );
                                                  }
                                                },
                                                child: Text(LocalizationService.getString('btn_ok')),
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                    },
                                    child: Container(
                                      width: 40,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Center(child: Text(quantity.toString(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => incrementQuantity(product.id),
                                    icon: const Icon(Icons.add),
                                    iconSize: 16,
                                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                    padding: EdgeInsets.zero,
                                    style: IconButton.styleFrom(
                                      side: const BorderSide(color: Colors.grey),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : InkWell(
                      onTap: () => addToSoldItems(product, quantity),
                      borderRadius: BorderRadius.circular(20),
                      splashColor: Colors.white.withValues(alpha: 0.3),
                      highlightColor: Colors.white.withValues(alpha: 0.1),
                      child: Column(
                        children: [
                          Container(
                            height: isTablet ? 200 : 300,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: product.imagePath != null && product.imagePath!.isNotEmpty
                                  ? Image.file(
                                      File(product.imagePath!),
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) =>
                                          const Icon(Icons.image, size: 80, color: Colors.grey),
                                    )
                                  : const Icon(Icons.image, size: 80, color: Colors.grey),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product.name,
                                  style: TextStyle(
                                    fontSize: isTablet ? 18 : 20,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  CurrencyService.formatCurrency(product.price),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.green,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (_hasDuplicatesWithSamePricing(product, filteredProducts))
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      'Giá vốn: ${CurrencyService.formatCurrency(product.costPrice)}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.purple[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(LocalizationService.getString('sales_quantity_sold'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                        const SizedBox(height: 4),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              onPressed: () => decrementQuantity(product.id),
                                              icon: const Icon(Icons.remove),
                                              iconSize: 18,
                                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                              padding: EdgeInsets.zero,
                                              style: IconButton.styleFrom(
                                                side: const BorderSide(color: Colors.grey),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                              ),
                                            ),
                                            GestureDetector(
                                              onTap: () {
                                                final controller = TextEditingController(text: quantity.toString());
                                                showDialog(
                                                  context: context,
                                                  builder: (BuildContext context) {
                                                    return AlertDialog(
                                                      title: Text(LocalizationService.getString('sales_enter_quantity')),
                                                      content: Column(
                                                        mainAxisSize: MainAxisSize.min,
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          FutureBuilder<Product?>(
                                                            future: _productService.getProductById(product.id),
                                                            builder: (context, snapshot) {
                                                              final currentProduct = snapshot.data ?? product;
                                                              return Text(
                                                                '${LocalizationService.getString('sales_in_stock')}: ${currentProduct.stock} ${currentProduct.unit}',
                                                                style: TextStyle(
                                                                  fontSize: 13,
                                                                  color: Theme.of(context).brightness == Brightness.dark
                                                                    ? Colors.white
                                                                    : Colors.black,
                                                                ),
                                                              );
                                                            },
                                                          ),
                                                          const SizedBox(height: 12),
                                                          TextField(
                                                            controller: controller,
                                                            keyboardType: TextInputType.number,
                                                            autofocus: true,
                                                            decoration: InputDecoration(
                                                              labelText: LocalizationService.getString('sales_quantity_want_to_sell'),
                                                              border: const OutlineInputBorder(),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () => Navigator.pop(context),
                                                          child: Text(LocalizationService.getString('btn_cancel')),
                                                        ),
                                                        ElevatedButton(
                                                          onPressed: () {
                                                            final newQuantity = int.tryParse(controller.text);
                                                            if (newQuantity != null && newQuantity > 0) {
                                                              setState(() => quantities[product.id] = newQuantity);
                                                              Navigator.pop(context);
                                                            } else {
                                                              ScaffoldMessenger.of(context).showSnackBar(
                                                                SnackBar(content: Text(LocalizationService.getString('sales_invalid_quantity'))),
                                                              );
                                                            }
                                                          },
                                                          child: Text(LocalizationService.getString('btn_ok')),
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                );
                                              },
                                              child: Container(
                                                width: 50,
                                                height: 36,
                                                decoration: BoxDecoration(
                                                  border: Border.all(color: Colors.grey),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Center(child: Text(quantity.toString(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                                              ),
                                            ),
                                            IconButton(
                                              onPressed: () => incrementQuantity(product.id),
                                              icon: const Icon(Icons.add),
                                              iconSize: 18,
                                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                              padding: EdgeInsets.zero,
                                              style: IconButton.styleFrom(
                                                side: const BorderSide(color: Colors.grey),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
            );
          },
        ),
        );
      },
    );
  }

  /// Build 2-column grid layout with name, price, cost price, and image - Responsive
  Widget _buildGridLayout2Columns() {
    return ResponsiveBuilder(
      builder: (context, sizingInformation) {
        final isMobile = sizingInformation.isMobile;
        
        // Determine number of columns based on screen size
        int crossAxisCount = 2;
        double childAspectRatio = 0.75;
        double spacing = 8;
        
        if (sizingInformation.isDesktop) {
          crossAxisCount = 4;
          childAspectRatio = 0.7;
          spacing = 12;
        } else if (sizingInformation.isTablet) {
          crossAxisCount = 3;
          childAspectRatio = 0.72;
          spacing = 10;
        }
        
        return RepaintBoundary(
          child: GridView.builder(
            padding: EdgeInsets.only(
              left: isMobile ? 8 : 12,
              right: isMobile ? 8 : 12,
              top: 8,
            bottom: 100,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: childAspectRatio,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
          ),
          itemCount: filteredProducts.length,
          itemBuilder: (context, index) {
            final product = filteredProducts[index];
            
            if (!_productColorCache.containsKey(product.id)) {
              _extractColorsFromImage(product);
            }
            
            return Card(
              elevation: 5,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: InkWell(
                onTap: () => addToSoldItems(product, 1),
                borderRadius: BorderRadius.circular(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: product.imagePath != null && product.imagePath!.isNotEmpty
                              ? Image.file(
                                  File(product.imagePath!),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(Icons.image, size: 60, color: Colors.grey),
                                )
                              : const Icon(Icons.image, size: 60, color: Colors.grey),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            product.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            CurrencyService.formatCurrency(product.price),
                            style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600),
                          ),
                          if (_hasDuplicatesWithSamePricing(product, filteredProducts))
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                'Vốn: ${CurrencyService.formatCurrency(product.costPrice)}',
                                style: TextStyle(fontSize: 10, color: Colors.purple[600]),
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
        ),
        );
      },
    );
  }

  /// Build simple grid layout with only name and image - Responsive
  Widget _buildSimpleGridLayout() {
    return ResponsiveBuilder(
      builder: (context, sizingInformation) {
        // Determine number of columns based on screen size
        int crossAxisCount = 3;
        double childAspectRatio = 0.8;
        double spacing = 6;
        
        if (sizingInformation.isDesktop) {
          crossAxisCount = 6;
          childAspectRatio = 0.8;
          spacing = 8;
        } else if (sizingInformation.isTablet) {
          crossAxisCount = 4;
          childAspectRatio = 0.8;
          spacing = 7;
        }
        
        return RepaintBoundary(
          child: GridView.builder(
            padding: const EdgeInsets.only(left: 8, right: 8, top: 8, bottom: 100),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: childAspectRatio,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
          ),
          itemCount: filteredProducts.length,
          itemBuilder: (context, index) {
            final product = filteredProducts[index];
            
            if (!_productColorCache.containsKey(product.id)) {
              _extractColorsFromImage(product);
            }
            
            return Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: InkWell(
                onTap: () => addToSoldItems(product, 1),
                borderRadius: BorderRadius.circular(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: product.imagePath != null && product.imagePath!.isNotEmpty
                              ? Image.file(
                                  File(product.imagePath!),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(Icons.image, size: 50, color: Colors.grey),
                                )
                              : const Icon(Icons.image, size: 50, color: Colors.grey),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            product.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            CurrencyService.formatCurrency(product.price),
                            style: const TextStyle(fontSize: 14, color: Colors.green, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        );
      },
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    soldItemsScrollController.dispose();
    _audioPlayer?.dispose();
    super.dispose();
  }

  Widget _buildSearchAndControlsSection() {
    return Column(
      children: [
        // Search Bar with Add Button and Delete Button
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 25.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: LocalizationService.getString('sales_search_product'),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              searchController.clear();
                            },
                          )
                        : null,
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
                        width: 4,
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
              // Layout Change Button
              IconButton(
                icon: const Icon(Icons.view_list_rounded, size: 30, color: Colors.blue),
                onPressed: () {
                  setState(() {
                    _layoutMode = (_layoutMode + 1) % 3;
                  });
                },
                style: IconButton.styleFrom(
                  side: const BorderSide(
                    color: Colors.grey,
                    width: 2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Sort buttons section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                SizedBox(
                  width: 110,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _sortBy = 'bestselling';
                        _filterProducts();
                      });
                    },
                    icon: const Icon(Icons.local_fire_department, size: 18, color: Colors.orange),
                    label: Text(LocalizationService.getString('sales_bestselling'), style: const TextStyle(fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      elevation: 4,
                      backgroundColor: _sortBy == 'bestselling' ? Colors.blue : Colors.grey[300],
                      foregroundColor: _sortBy == 'bestselling' ? Colors.white : Colors.black87,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 100,
                  child: ElevatedButton(
                    onPressed: () {
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
                    style: ElevatedButton.styleFrom(
                      elevation: 4,
                      backgroundColor: _sortBy == 'name' ? const Color.fromARGB(255, 233, 247, 114) : Colors.grey[300],
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.sort_by_alpha, size: 16, color: Colors.blue),
                        const SizedBox(width: 2),
                        Text(LocalizationService.getString('sales_product_name'), style: const TextStyle(fontSize: 12)),
                        if (_sortBy == 'name')
                          const SizedBox(width: 2),
                        if (_sortBy == 'name')
                          Icon(
                            _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                            size: 10,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 115,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        if (_sortBy == 'price') {
                          _sortAscending = !_sortAscending;
                        } else {
                          _sortBy = 'price';
                          _sortAscending = false;
                        }
                        _filterProducts();
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      elevation: 4,
                      backgroundColor: _sortBy == 'price' ? const Color.fromARGB(255, 255, 151, 53) : Colors.grey[300],
                      foregroundColor: _sortBy == 'price' ? Colors.white : Colors.black87,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.attach_money, size: 16, color: Colors.green),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            LocalizationService.getString('sales_selling_price'),
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_sortBy == 'price')
                          const SizedBox(width: 2),
                        if (_sortBy == 'price')
                          Icon(
                            _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                            size: 10,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Column(
            children: [
              RepaintBoundary(
                child: _buildSearchAndControlsSection(),
              ),
              // Product List
              Expanded(
                child: filteredProducts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.search_off,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              LocalizationService.getString('sales_no_products'),
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              LocalizationService.getString('sales_go_to_product_management'),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            // Generate test data button
                            ElevatedButton.icon(
                              onPressed: () async {
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      title: Text(LocalizationService.getString('sales_generate_test_data')),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          CircularProgressIndicator(),
                                          SizedBox(height: 16),
                                          Text(LocalizationService.getString('sales_please_wait')),
                                        ],
                                      ),
                                    );
                                  },
                                );

                                try {
                                  await TestDataGenerator.generateTestData();
                                  
                                  // Dismiss loading dialog
                                  if (!context.mounted) return;
                                  Navigator.of(context).pop();

                                  // Reload data
                                  await _initializeData();

                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('✅ ${LocalizationService.getString("sales_test_data_created")}'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                } catch (e) {
                                  // Dismiss loading dialog
                                  if (!context.mounted) return;
                                  Navigator.of(context).pop();

                                  if(!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('❌ Lỗi: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.add_box),
                              label: Text(LocalizationService.getString('sales_generate_test_data')),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Go to Product Management button
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const ProductManagementPage(),
                                  ),
                                ).then((_) {
                                  // Reload data when returning from product management
                                  _initializeData();
                                });
                              },
                              icon: const Icon(Icons.shopping_bag),
                              label: Text(LocalizationService.getString('nav_product_management')),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purple,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : _layoutMode == 0
                        ? _buildListLayout()
                        : _layoutMode == 1
                            ? _buildGridLayout2Columns()
                            : _buildSimpleGridLayout(),
              ),
            ],
          ),
          // Sold Items Section - Fixed at bottom
          if (soldItems.isNotEmpty && _showSoldItems)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                color: const Color.fromARGB(255, 26, 27, 80),
                padding: const EdgeInsets.all(8),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 8, bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            LocalizationService.getString('sales_sold_today'),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _showSoldItems = false;
                              });
                            },
                            icon: const Icon(Icons.visibility_off, size: 16),
                            label: Text(LocalizationService.getString('sales_hide'), style: const TextStyle(fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              textStyle: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: RawScrollbar(
                        controller: soldItemsScrollController,
                        thickness: 10,
                        thumbColor: Colors.black54,
                        radius: const Radius.circular(4),
                        thumbVisibility: true,
                        child: ListView.builder(
                          controller: soldItemsScrollController,
                          scrollDirection: Axis.vertical,
                          itemCount: soldItems.length,
                          itemBuilder: (context, index) {
                            final item = soldItems[index];
                            final timeString =
                                '${item.timestamp.hour.toString().padLeft(2, '0')}:${item.timestamp.minute.toString().padLeft(2, '0')}:${item.timestamp.second.toString().padLeft(2, '0')}';
                            return InkWell(
                              onTap: () {
                                // Show full info dialog
                                showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      title: const Text('Thông tin chi tiết'),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              const Text(
                                                'STT: ',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Text('${index + 1}'),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              const Text(
                                                'Tên mặt hàng: ',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Expanded(
                                                child: Text(
                                                  item.product?.name ??
                                                      'Unknown',
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              const Text(
                                                'Số lượng: ',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Text('${item.quantity}'),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              const Text(
                                                'Giá đơn vị: ',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Text(
                                                '${(item.product?.price ?? 0).toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')} VND',
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              const Text(
                                                'Tổng tiền: ',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.green,
                                                ),
                                              ),
                                              Text(
                                                '${item.totalPrice.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')} VND',
                                                style: const TextStyle(
                                                  color: Colors.green,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              const Text(
                                                'Thời gian: ',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Text(
                                                '$timeString - ${item.timestamp.day}/${item.timestamp.month}/${item.timestamp.year}',
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: const Text('Đóng'),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                              child: Card(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 2,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 15,
                                  ),
                                  child: Row(
                                    children: [
                                      // Index number
                                      Container(
                                        width: 30,
                                        alignment: Alignment.center,
                                        child: Text(
                                          '${index + 1}.',
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Product name, quantity, time
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Flexible(
                                              flex: 2,
                                              child: Text(
                                                item.product?.name ?? 'Unknown',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Flexible(
                                              flex: 1,
                                              child: Text(
                                                'SL:${item.quantity}',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Flexible(
                                              flex: 1,
                                              child: Text(
                                                timeString,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () =>
                                            removeSoldItem(soldItems[index].id),
                                        icon: const Icon(
                                          Icons.close,
                                          size: 20,
                                          color: Colors.red,
                                        ),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                          minWidth: 25,
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
                    ),
                  ],
                ),
              ),
            ),

          // Show Button for Sold Items Section (when hidden and items exist) - Fixed at bottom
          if (soldItems.isNotEmpty && !_showSoldItems)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF2A2A2A)
                    : Colors.blue[100],
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${LocalizationService.getString('sales_sold_today')}: ${soldItems.length}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black,
                      ),
                    ),
                    Text(
                      '+ ${CurrencyService.formatCurrency(soldItems.fold<int>(0, (sum, item) => sum + item.totalPrice))},',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _showSoldItems = true;
                        });
                      },
                      icon: const Icon(Icons.visibility, size: 16),
                      label: Text(LocalizationService.getString('sales_show'), style: const TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
