import 'package:flutter/material.dart';
import 'dart:io';
import 'package:just_audio/just_audio.dart';
import 'models/product_model.dart';
import 'models/sold_item_model.dart';
import 'services/product_service.dart';

class SalesPage extends StatefulWidget {
  final bool soundEnabled;

  const SalesPage({
    super.key,
    this.soundEnabled = true,
  });

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  final TextEditingController searchController = TextEditingController();
  final ScrollController soldItemsScrollController = ScrollController();
  bool _showSoldItems = false;

  final ProductService _productService = ProductService();
  late AudioPlayer _audioPlayer;
  bool _audioPlayerInitialized = false;

  late List<Product> allProducts;
  late List<Product> filteredProducts;
  late List<SoldItem> soldItems;

  final Map<int, int> quantities = {};
  String _sortBy = 'name'; // 'bestselling', 'name', 'price'
  bool _sortAscending = true; // true = ascending, false = descending
  
  // Cache for extracted image colors
  final Map<int, List<Color>> _productColorCache = {};

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


  @override
  void initState() {
    super.initState();
    allProducts = [];
    filteredProducts = [];
    soldItems = [];
    _initializeData();
    searchController.addListener(_filterProducts);
    _initializeAudioPlayer();
  }

  Future<void> _initializeAudioPlayer() async {
    try {
      _audioPlayer = AudioPlayer();
      _audioPlayerInitialized = true;
    } catch (e) {
      print('Error initializing audio player: $e');
      _audioPlayerInitialized = false;
    }
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
        filteredProducts = products;
        soldItems = sold;

        // Initialize quantities
        for (var product in allProducts) {
          quantities[product.id] = 1;
        }
      });
      
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
      // Sort by number of sales today
      filtered.sort((a, b) {
        final aSalesCount = soldItems
            .where((item) => item.productId == a.id)
            .fold<int>(0, (sum, item) => sum + item.quantity);
        final bSalesCount = soldItems
            .where((item) => item.productId == b.id)
            .fold<int>(0, (sum, item) => sum + item.quantity);
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

  void addToSoldItems(Product product, int quantity) async {
    try {
      final totalPrice = product.price * quantity;

      // Save to database
      final success = await _productService.addSoldItem(
        productId: product.id,
        quantity: quantity,
        totalPrice: totalPrice,
      );

      if (success) {
        // Play success sound with error handling (only if sound is enabled)
        if (_audioPlayerInitialized && widget.soundEnabled) {
          try {
            // Play sound from assets
            await _audioPlayer.setAsset('assets/sounds/Kaching.mp3');
            await _audioPlayer.play();
          } catch (audioError) {
            print('Audio playback error: $audioError');
            // Continue with the sale even if sound fails
          }
        }

        // Decrease product stock
        final newStock = product.stock - quantity;
        if (newStock >= 0) {
          final updatedProduct = product.copyWith(stock: newStock);
          await _productService.updateProduct(updatedProduct);
        }

        // Reset quantity after sale
        quantities[product.id] = 1;

        // Load sold items from database
        await _loadTodaySoldItems();

        // Check if widget is still mounted before showing snackbar
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${product.name} x$quantity đã bán'),
            duration: const Duration(milliseconds: 500),
            backgroundColor: Colors.green,
          ),
        );
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

  @override
  void dispose() {
    searchController.dispose();
    soldItemsScrollController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Column(
            children: [
              // Search Bar with Add Button and Delete Button
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 45.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: searchController,
                        decoration: InputDecoration(
                          hintText: 'Tìm kiếm mặt hàng',
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
                  ],
                ),
              ),
              // Sort buttons section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 0),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _sortBy = 'bestselling';
                            _filterProducts();
                          });
                        },
                        icon: const Icon(Icons.local_fire_department, size: 20, color: Colors.orange),
                        label: const Text('Bán chạy', style: TextStyle(fontSize: 15)),
                        style: ElevatedButton.styleFrom(
                          elevation: 4,
                          backgroundColor: _sortBy == 'bestselling' ? Colors.blue : Colors.grey[300],
                          foregroundColor: _sortBy == 'bestselling' ? Colors.white : Colors.black87,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
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
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.sort_by_alpha, size: 20, color: Colors.blue),
                            const SizedBox(width: 4),
                            const Text('Tên', style: TextStyle(fontSize: 15)),
                            const SizedBox(width: 4),
                            if (_sortBy == 'name')
                              Icon(
                                _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                                size: 12,
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            if (_sortBy == 'price') {
                              _sortAscending = !_sortAscending;
                            } else {
                              _sortBy = 'price';
                              _sortAscending = false; // Default descending for price (highest first)
                            }
                            _filterProducts();
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          elevation: 4,
                          backgroundColor: _sortBy == 'price' ? const Color.fromARGB(255, 255, 151, 53) : Colors.grey[300],
                          foregroundColor: _sortBy == 'price' ? Colors.white : Colors.black87,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.attach_money, size: 20, color: Colors.green),
                            const SizedBox(width: 4),
                            const Text('Giá bán', style: TextStyle(fontSize: 15)),
                            const SizedBox(width: 4),
                            if (_sortBy == 'price')
                              Icon(
                                _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                                size: 12,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
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
                              'No products found',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 100),
                        itemCount: filteredProducts.length,
                        itemBuilder: (context, index) {
                          final product = filteredProducts[index];
                          final quantity = quantities[product.id] ?? 1;
                          
                          // Extract colors asynchronously on first build
                          if (!_productColorCache.containsKey(product.id)) {
                            _extractColorsFromImage(product);
                          }
                          
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            elevation: 10,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                // Product Info and Image (Clickable)
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).brightness == Brightness.dark
                                          ? const Color.fromARGB(116, 20, 5, 5)
                                          : const Color.fromARGB(255, 255, 253, 191),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () {
                                          // Add product to sold items
                                          // SnackBar feedback is handled inside addToSoldItems()
                                          addToSoldItems(product, quantity);
                                        },
                                        borderRadius: BorderRadius.circular(20),
                                        splashColor: Colors.white.withValues(alpha: 0.3),
                                        highlightColor: Colors.white.withValues(alpha: 0.1),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                          vertical: 5,
                                          horizontal: 15,
                                          ),
                                      child: Row(
                                        children: [
                                          // Product Info
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
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
                                                  '${product.price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')} VND',
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.green,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                // Show cost price if product has duplicates with same name and price
                                                if (_hasDuplicatesWithSamePricing(product, filteredProducts))
                                                  Padding(
                                                    padding: const EdgeInsets.only(top: 4),
                                                    child: Text(
                                                      'Giá vốn: ${product.costPrice.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')} VND',
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
                                          // Product Image or Placeholder
                                          Container(
                                            width: 60,
                                            height: 60,
                                            margin: const EdgeInsets.only(
                                              left: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.grey[300],
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(8),
                                              child: product.imagePath != null && 
                                                     product.imagePath!.isNotEmpty
                                                ? Image.file(
                                                    File(product.imagePath!),
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (context, error, stackTrace) {
                                                      return const Icon(
                                                        Icons.image,
                                                        size: 30,
                                                        color: Colors.grey,
                                                      );
                                                    },
                                                  )
                                                : const Icon(
                                                    Icons.image,
                                                    size: 30,
                                                    color: Colors.grey,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                      ),
                                    ),
                                  ),
                                ),
                                // Quantity Controls (Not clickable for selling)
                                Container(
                                  padding: const EdgeInsets.all(1),
                                  child: Column(
                                    children: [
                                      const Text(
                                        'Số lượng',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Decrement Button
                                          IconButton(
                                            onPressed: () =>
                                                decrementQuantity(product.id),
                                            icon: const Icon(Icons.remove),
                                            iconSize: 16,
                                            constraints: const BoxConstraints(
                                              minWidth: 28,
                                              minHeight: 28,
                                            ),
                                            padding: EdgeInsets.zero,
                                            style: IconButton.styleFrom(
                                              side: const BorderSide(
                                                color: Colors.grey,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                            ),
                                          ),
                                          // Quantity Display (Editable)
                                          GestureDetector(
                                            onTap: () {
                                              final controller =
                                                  TextEditingController(
                                                    text: quantity.toString(),
                                                  );
                                              showDialog(
                                                context: context,
                                                builder: (BuildContext context) {
                                                  return AlertDialog(
                                                    title: const Text(
                                                      'Nhập số lượng',
                                                    ),
                                                    content: Column(
                                                      mainAxisSize: MainAxisSize.min,
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          'Trong kho: ${product.stock} ${product.unit}',
                                                          style: TextStyle(
                                                            fontSize: 13,
                                                            color: Colors.black,
                                                          ),
                                                        ),
                                                        const SizedBox(height: 12),
                                                        TextField(
                                                          controller: controller,
                                                          keyboardType:
                                                              TextInputType.number,
                                                          autofocus: true,
                                                          decoration:
                                                              const InputDecoration(
                                                                labelText:
                                                                    'Số lượng muôn bán',
                                                                border:
                                                                    OutlineInputBorder(),
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                              context,
                                                            ),
                                                        child: const Text(
                                                          'Hủy',
                                                        ),
                                                      ),
                                                      ElevatedButton(
                                                        onPressed: () {
                                                          final newQuantity =
                                                              int.tryParse(
                                                                controller.text,
                                                              );
                                                          if (newQuantity !=
                                                                  null &&
                                                              newQuantity > 0) {
                                                            setState(() {
                                                              quantities[product
                                                                      .id] =
                                                                  newQuantity;
                                                            });
                                                            Navigator.pop(
                                                              context,
                                                            );
                                                          } else {
                                                            ScaffoldMessenger.of(
                                                              context,
                                                            ).showSnackBar(
                                                              const SnackBar(
                                                                content: Text(
                                                                  'Vui lòng nhập số lượng hợp lệ (> 0)',
                                                                ),
                                                              ),
                                                            );
                                                          }
                                                        },
                                                        child: const Text('OK'),
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
                                                border: Border.all(
                                                  color: Colors.grey,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  quantity.toString(),
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          // Increment Button
                                          IconButton(
                                            onPressed: () =>
                                                incrementQuantity(product.id),
                                            icon: const Icon(Icons.add),
                                            iconSize: 16,
                                            constraints: const BoxConstraints(
                                              minWidth: 28,
                                              minHeight: 28,
                                            ),
                                            padding: EdgeInsets.zero,
                                            style: IconButton.styleFrom(
                                              side: const BorderSide(
                                                color: Colors.grey,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
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
                            'Đã bán hôm nay',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white
                                  : Colors.black,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _showSoldItems = false;
                              });
                            },
                            icon: const Icon(Icons.visibility_off, size: 16),
                            label: const Text('Ẩn'),
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
                                  vertical: 1,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 1,
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
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Flexible(
                                              flex: 3,
                                              child: Text(
                                                item.product?.name ?? 'Unknown',
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 15),
                                            Text(
                                              'SL: ${item.quantity}',
                                              style: TextStyle(
                                                fontSize: 15,
                                                color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
                                              ),
                                            ),
                                            const SizedBox(width: 15),
                                            Text(
                                              timeString,
                                              style: TextStyle(
                                                fontSize: 15,
                                                color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
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
                    : Colors.blue[50],
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Đã bán hôm nay: ${soldItems.length}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black,
                      ),
                    ),
                    Text(
                      '+ ${soldItems.fold<int>(0, (sum, item) => sum + item.totalPrice).toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')} VND',
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
                      label: const Text('Hiển thị'),
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
