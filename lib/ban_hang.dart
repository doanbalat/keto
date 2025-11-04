import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'models/product_model.dart';
import 'models/sold_item_model.dart';
import 'services/product_service.dart';

class SalesPage extends StatefulWidget {
  const SalesPage({super.key});

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

  /// Check if a product has duplicates with the same name and price
  bool _hasDuplicatesWithSamePricing(Product product, List<Product> productList) {
    return productList.where((p) => 
      p.name == product.name && 
      p.price == product.price && 
      p.id != product.id
    ).isNotEmpty;
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
        // Play success sound with error handling
        if (_audioPlayerInitialized) {
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

  void _showAddProductDialog(BuildContext context) {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final costPriceController = TextEditingController();
    final quantityController = TextEditingController(text: '0');
    final unitController = TextEditingController(text: 'cái');
    File? selectedImage;
    final ImagePicker _picker = ImagePicker();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [Colors.white, Colors.grey[50]!],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
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
                          colors: [Colors.blue[600]!, Colors.blue[400]!],
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
                              const Text(
                                'Thêm mặt hàng mới',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Quản lý kho hàng',
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
                                      color: Colors.blue[200]!,
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
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.image_outlined,
                                              size: 40,
                                              color: Colors.blue[300],
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              'Chọn ảnh mặt hàng',
                                              style: TextStyle(
                                                color: Colors.blue[400],
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
                                  labelText: 'Tên sản phẩm',
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
                                      color: Colors.blue,
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
                                  labelText: 'Giá bán (VND)',
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
                                      color: Colors.blue,
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
                                  labelText: 'Giá vốn (VND)',
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
                                      color: Colors.blue,
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
                                  labelText: 'Số lượng hàng',
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
                                      color: Colors.blue,
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
                                  labelText: 'Đơn vị (cái, kg, ly, hộp, phần, ...)',
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
                                      color: Colors.blue,
                                      width: 2,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
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
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                side: BorderSide(
                                  color: Colors.grey[300]!,
                                  width: 1.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Hủy',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
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
                                      const SnackBar(
                                        content: Text('Vui lòng điền đầy đủ thông tin'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                    return;
                                  }

                                  final name = nameController.text;
                                  final price = int.parse(priceController.text);
                                  final costPrice = int.parse(costPriceController.text);
                                  final quantity = int.parse(quantityController.text);
                                  final unit = unitController.text.isEmpty ? 'cái' : unitController.text;

                                  if (price <= 0 || costPrice <= 0 || quantity < 0) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Giá phải dương, số lượng không được âm'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                    return;
                                  }

                                  // Add product with initial quantity directly
                                  final productId = await _productService.addProduct(
                                    name,
                                    price,
                                    costPrice,
                                    unit: unit,
                                    stock: quantity,
                                  );

                                  if (productId == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Lỗi khi thêm sản phẩm'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                    return;
                                  }

                                  if (!mounted) return;
                                  Navigator.pop(context);

                                  await _initializeData();

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Thêm sản phẩm "$name" thành công'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                } catch (e) {
                                  ScaffoldMessenger.of(
                                    context,
                                  ).showSnackBar(
                                    SnackBar(
                                      content: Text('Lỗi: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Thêm',
                                style: TextStyle(
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
                padding: const EdgeInsets.all(12.0),
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
                    const SizedBox(width: 5),
                    ElevatedButton(
                      onPressed: () {
                        _showAddProductDialog(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(50),
                        ),
                      ),
                      child: const Icon(Icons.add, size: 32),
                    ),
                    const SizedBox(width: 5),
                    ElevatedButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) {
                            String sortBy =
                                'name'; // 'name', 'quantity', 'price'
                            return StatefulBuilder(
                              builder: (context, setDialogState) {
                                // Sort products based on selected option
                                List<Product> sortedProducts = List.from(
                                  allProducts,
                                );
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
                                      gradient: LinearGradient(
                                        colors: [Colors.white, Colors.grey[50]!],
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        // Header with gradient
                                        Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [Colors.red[600]!, Colors.red[400]!],
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
                                                  Icons.delete_outline,
                                                  color: Colors.white,
                                                  size: 28,
                                                ),
                                              ),
                                              const SizedBox(width: 16),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                    'Xóa Sản Phẩm',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 22,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'Quản lý sản phẩm',
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
                                                  icon: const Icon(Icons.sort_by_alpha, size: 16),
                                                  label: const Text('Tên', style: TextStyle(fontSize: 12)),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: sortBy == 'name' ? Colors.blue : Colors.grey[200],
                                                    foregroundColor: sortBy == 'name' ? Colors.white : Colors.black87,
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(8),
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
                                                  icon: const Icon(Icons.inventory, size: 16),
                                                  label: const Text('Số lượng', style: TextStyle(fontSize: 12)),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: sortBy == 'quantity' ? Colors.blue : Colors.grey[200],
                                                    foregroundColor: sortBy == 'quantity' ? Colors.white : Colors.black87,
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(8),
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
                                                  icon: const Icon(Icons.attach_money, size: 16),
                                                  label: const Text('Giá', style: TextStyle(fontSize: 12)),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: sortBy == 'price' ? Colors.blue : Colors.grey[200],
                                                    foregroundColor: sortBy == 'price' ? Colors.white : Colors.black87,
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(8),
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
                                              final product = sortedProducts[index];
                                              return Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                                child: InkWell(
                                                  onTap: () {
                                                    showDialog(
                                                      context: context,
                                                      builder: (context) {
                                                        return Dialog(
                                                          shape: RoundedRectangleBorder(
                                                            borderRadius: BorderRadius.circular(16),
                                                          ),
                                                          child: Container(
                                                            decoration: BoxDecoration(
                                                              borderRadius: BorderRadius.circular(16),
                                                              gradient: LinearGradient(
                                                                colors: [Colors.white, Colors.grey[50]!],
                                                                begin: Alignment.topCenter,
                                                                end: Alignment.bottomCenter,
                                                              ),
                                                            ),
                                                            padding: const EdgeInsets.all(24),
                                                            child: Column(
                                                              mainAxisSize: MainAxisSize.min,
                                                              children: [
                                                                // Warning icon
                                                                Container(
                                                                  decoration: BoxDecoration(
                                                                    color: Colors.red[50],
                                                                    borderRadius: BorderRadius.circular(50),
                                                                  ),
                                                                  padding: const EdgeInsets.all(16),
                                                                  child: Icon(
                                                                    Icons.warning_rounded,
                                                                    size: 40,
                                                                    color: Colors.red[600],
                                                                  ),
                                                                ),
                                                                const SizedBox(height: 20),
                                                                // Title
                                                                const Text(
                                                                  'Xác nhận xóa',
                                                                  style: TextStyle(
                                                                    fontSize: 20,
                                                                    fontWeight: FontWeight.bold,
                                                                  ),
                                                                ),
                                                                const SizedBox(height: 12),
                                                                // Product info card
                                                                Container(
                                                                  decoration: BoxDecoration(
                                                                    color: Colors.blue[50],
                                                                    borderRadius: BorderRadius.circular(12),
                                                                    border: Border.all(
                                                                      color: Colors.blue[200]!,
                                                                      width: 1,
                                                                    ),
                                                                  ),
                                                                  padding: const EdgeInsets.all(16),
                                                                  child: Column(
                                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                                    children: [
                                                                      Row(
                                                                        children: [
                                                                          Expanded(
                                                                            child: Column(
                                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                                              children: [
                                                                                Text(
                                                                                  'Tên sản phẩm',
                                                                                  style: TextStyle(
                                                                                    fontSize: 12,
                                                                                    color: Colors.grey[600],
                                                                                    fontWeight: FontWeight.w500,
                                                                                  ),
                                                                                ),
                                                                                const SizedBox(height: 4),
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
                                                                              borderRadius: BorderRadius.circular(8),
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
                                                                      const SizedBox(height: 16),
                                                                      // Prices section
                                                                      Row(
                                                                        children: [
                                                                          Expanded(
                                                                            child: Column(
                                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                                              children: [
                                                                                Text(
                                                                                  'Giá bán',
                                                                                  style: TextStyle(
                                                                                    fontSize: 12,
                                                                                    color: Colors.grey[600],
                                                                                    fontWeight: FontWeight.w500,
                                                                                  ),
                                                                                ),
                                                                                const SizedBox(height: 4),
                                                                                Text(
                                                                                  NumberFormat.currency(
                                                                                    locale: 'vi',
                                                                                    symbol: 'đ',
                                                                                    decimalDigits: 0,
                                                                                  ).format(product.price),
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
                                                                                  'Giá vốn',
                                                                                  style: TextStyle(
                                                                                    fontSize: 12,
                                                                                    color: Colors.grey[600],
                                                                                    fontWeight: FontWeight.w500,
                                                                                  ),
                                                                                ),
                                                                                const SizedBox(height: 4),
                                                                                Text(
                                                                                  NumberFormat.currency(
                                                                                    locale: 'vi',
                                                                                    symbol: 'đ',
                                                                                    decimalDigits: 0,
                                                                                  ).format(product.costPrice),
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
                                                                const SizedBox(height: 20),
                                                                // Warning text
                                                                RichText(
                                                                  textAlign: TextAlign.center,
                                                                  text: TextSpan(
                                                                    style: TextStyle(
                                                                      fontSize: 14,
                                                                      color: Colors.grey[700],
                                                                    ),
                                                                    children: [
                                                                      const TextSpan(
                                                                        text: 'Bạn có chắc chắn muốn xóa ',
                                                                      ),
                                                                      TextSpan(
                                                                        text: '\"${product.name}\"',
                                                                        style: const TextStyle(
                                                                          fontWeight: FontWeight.bold,
                                                                          color: Colors.red,
                                                                        ),
                                                                      ),
                                                                      const TextSpan(
                                                                        text: '? Hành động này không thể hoàn tác.',
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                                const SizedBox(height: 24),
                                                                // Action buttons
                                                                Row(
                                                                  children: [
                                                                    Expanded(
                                                                      child: TextButton(
                                                                        onPressed: () =>
                                                                            Navigator.pop(context),
                                                                        style: TextButton.styleFrom(
                                                                          padding: const EdgeInsets.symmetric(
                                                                            vertical: 12,
                                                                          ),
                                                                          shape: RoundedRectangleBorder(
                                                                            borderRadius: BorderRadius.circular(8),
                                                                            side: const BorderSide(
                                                                              color: Colors.grey,
                                                                              width: 1,
                                                                            ),
                                                                          ),
                                                                        ),
                                                                        child: const Text(
                                                                          'Hủy',
                                                                          style: TextStyle(
                                                                            fontSize: 14,
                                                                            fontWeight: FontWeight.w600,
                                                                            color: Colors.grey,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    const SizedBox(width: 12),
                                                                    Expanded(
                                                                      child: ElevatedButton(
                                                                        onPressed: () async {
                                                                          try {
                                                                            final success =
                                                                                await _productService
                                                                                    .hardDeleteProduct(
                                                                                      product.id,
                                                                                    );

                                                                            if (success) {
                                                                              final products =
                                                                                  await _productService
                                                                                      .getAllProducts();

                                                                              if (!mounted) return;

                                                                              setState(() {
                                                                                allProducts =
                                                                                    products;
                                                                                quantities
                                                                                    .remove(
                                                                                      product
                                                                                          .id,
                                                                                    );
                                                                                _filterProducts();
                                                                              });

                                                                              if (!mounted) return;
                                                                              Navigator.pop(context);
                                                                              Navigator.pop(context);

                                                                              ScaffoldMessenger.of(
                                                                                context,
                                                                              ).showSnackBar(
                                                                                SnackBar(
                                                                                  content: Text(
                                                                                    'Đã xóa "${product.name}"',
                                                                                  ),
                                                                                  backgroundColor:
                                                                                      Colors.green,
                                                                                ),
                                                                              );
                                                                            } else {
                                                                              if (!mounted) return;
                                                                              Navigator.pop(context);
                                                                              ScaffoldMessenger.of(
                                                                                context,
                                                                              ).showSnackBar(
                                                                                const SnackBar(
                                                                                  backgroundColor:
                                                                                      Colors.red,
                                                                                  content: Text(
                                                                                    'Lỗi khi xóa sản phẩm',
                                                                                  ),
                                                                                ),
                                                                              );
                                                                            }
                                                                          } catch (e) {
                                                                            if (!mounted) return;
                                                                            Navigator.pop(context);
                                                                            ScaffoldMessenger.of(
                                                                              context,
                                                                            ).showSnackBar(
                                                                              SnackBar(
                                                                                backgroundColor:
                                                                                    Colors.red,
                                                                                content: Text(
                                                                                  'Lỗi: $e',
                                                                                ),
                                                                              ),
                                                                            );
                                                                          }
                                                                        },
                                                                        style:
                                                                            ElevatedButton.styleFrom(
                                                                              backgroundColor:
                                                                                  Colors.red,
                                                                              foregroundColor:
                                                                                  Colors.white,
                                                                              padding: const EdgeInsets.symmetric(
                                                                                vertical: 12,
                                                                              ),
                                                                              shape: RoundedRectangleBorder(
                                                                                borderRadius: BorderRadius.circular(8),
                                                                              ),
                                                                            ),
                                                                        child: const Text(
                                                                          'Xóa',
                                                                          style: TextStyle(
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
                                                  borderRadius: BorderRadius.circular(12),
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      borderRadius: BorderRadius.circular(12),
                                                      color: Colors.white,
                                                    ),
                                                    padding: const EdgeInsets.all(12),
                                                    child: Row(
                                                      children: [
                                                        // Product number badge
                                                        Container(
                                                          width: 40,
                                                          height: 40,
                                                          decoration: BoxDecoration(
                                                            gradient: LinearGradient(
                                                              colors: [Colors.orange[400]!, Colors.orange[600]!],
                                                              begin: Alignment.topLeft,
                                                              end: Alignment.bottomRight,
                                                            ),
                                                            borderRadius: BorderRadius.circular(50),
                                                          ),
                                                          child: Center(
                                                            child: Text(
                                                              '${index + 1}',
                                                              style: const TextStyle(
                                                                color: Colors.white,
                                                                fontWeight: FontWeight.bold,
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
                                                                CrossAxisAlignment.start,
                                                            children: [
                                                              Text(
                                                                product.name,
                                                                style: const TextStyle(
                                                                  fontSize: 15,
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
                                                                      'Giá bán: ${NumberFormat.currency(locale: 'vi', symbol: 'đ', decimalDigits: 0).format(product.price)}',
                                                                      style: TextStyle(
                                                                        fontSize: 12,
                                                                        color: Colors.grey[600],
                                                                      ),
                                                                      maxLines: 1,
                                                                      overflow: TextOverflow.ellipsis,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                              const SizedBox(height: 2),
                                                              Text(
                                                                'Giá vốn: ${NumberFormat.currency(locale: 'vi', symbol: 'đ', decimalDigits: 0).format(product.costPrice)}',
                                                                style: TextStyle(
                                                                  fontSize: 12,
                                                                  color: Colors.grey[600],
                                                                ),
                                                                maxLines: 1,
                                                                overflow: TextOverflow.ellipsis,
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        const SizedBox(width: 12),
                                                        // Quantity info
                                                        Container(
                                                          decoration: BoxDecoration(
                                                            color: Colors.blue[50],
                                                            borderRadius: BorderRadius.circular(8),
                                                          ),
                                                          padding: const EdgeInsets.symmetric(
                                                            horizontal: 10,
                                                            vertical: 6,
                                                          ),
                                                          child: Column(
                                                            children: [
                                                              Text(
                                                                product.stock.toString(),
                                                                style: const TextStyle(
                                                                  fontSize: 16,
                                                                  fontWeight: FontWeight.bold,
                                                                  color: Colors.blue,
                                                                ),
                                                              ),
                                                              Text(
                                                                product.unit,
                                                                style: TextStyle(
                                                                  fontSize: 10,
                                                                  color: Colors.grey[600],
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
                                                            borderRadius: BorderRadius.circular(8),
                                                          ),
                                                          child: IconButton(
                                                            icon: Icon(
                                                              Icons.delete_outline,
                                                              color: Colors.red[600],
                                                              size: 20,
                                                            ),
                                                            onPressed: () {
                                                              showDialog(
                                                                context: context,
                                                                builder: (context) {
                                                                  return Dialog(
                                                                    shape: RoundedRectangleBorder(
                                                                      borderRadius: BorderRadius.circular(16),
                                                                    ),
                                                                    child: Container(
                                                                      decoration: BoxDecoration(
                                                                        borderRadius: BorderRadius.circular(16),
                                                                        gradient: LinearGradient(
                                                                          colors: [Colors.white, Colors.grey[50]!],
                                                                          begin: Alignment.topCenter,
                                                                          end: Alignment.bottomCenter,
                                                                        ),
                                                                      ),
                                                                      padding: const EdgeInsets.all(24),
                                                                      child: Column(
                                                                        mainAxisSize: MainAxisSize.min,
                                                                        children: [
                                                                          // Warning icon
                                                                          Container(
                                                                            decoration: BoxDecoration(
                                                                              color: Colors.red[50],
                                                                              borderRadius: BorderRadius.circular(50),
                                                                            ),
                                                                            padding: const EdgeInsets.all(16),
                                                                            child: Icon(
                                                                              Icons.warning_rounded,
                                                                              size: 40,
                                                                              color: Colors.red[600],
                                                                            ),
                                                                          ),
                                                                          const SizedBox(height: 20),
                                                                          // Title
                                                                          const Text(
                                                                            'Xác nhận xóa',
                                                                            style: TextStyle(
                                                                              fontSize: 20,
                                                                              fontWeight: FontWeight.bold,
                                                                            ),
                                                                          ),
                                                                          const SizedBox(height: 12),
                                                                          // Product info card
                                                                          Container(
                                                                            decoration: BoxDecoration(
                                                                              color: Colors.blue[50],
                                                                              borderRadius: BorderRadius.circular(12),
                                                                              border: Border.all(
                                                                                color: Colors.blue[200]!,
                                                                                width: 1,
                                                                              ),
                                                                            ),
                                                                            padding: const EdgeInsets.all(16),
                                                                            child: Column(
                                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                                              children: [
                                                                                Row(
                                                                                  children: [
                                                                                    Expanded(
                                                                                      child: Column(
                                                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                                                        children: [
                                                                                          Text(
                                                                                            'Tên sản phẩm',
                                                                                            style: TextStyle(
                                                                                              fontSize: 12,
                                                                                              color: Colors.grey[600],
                                                                                              fontWeight: FontWeight.w500,
                                                                                            ),
                                                                                          ),
                                                                                          const SizedBox(height: 4),
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
                                                                                        borderRadius: BorderRadius.circular(8),
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
                                                                                const SizedBox(height: 16),
                                                                                // Prices section
                                                                                Row(
                                                                                  children: [
                                                                                    Expanded(
                                                                                      child: Column(
                                                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                                                        children: [
                                                                                          Text(
                                                                                            'Giá bán',
                                                                                            style: TextStyle(
                                                                                              fontSize: 12,
                                                                                              color: Colors.grey[600],
                                                                                              fontWeight: FontWeight.w500,
                                                                                            ),
                                                                                          ),
                                                                                          const SizedBox(height: 4),
                                                                                          Text(
                                                                                            NumberFormat.currency(
                                                                                              locale: 'vi',
                                                                                              symbol: 'đ',
                                                                                              decimalDigits: 0,
                                                                                            ).format(product.price),
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
                                                                                            'Giá vốn',
                                                                                            style: TextStyle(
                                                                                              fontSize: 12,
                                                                                              color: Colors.grey[600],
                                                                                              fontWeight: FontWeight.w500,
                                                                                            ),
                                                                                          ),
                                                                                          const SizedBox(height: 4),
                                                                                          Text(
                                                                                            NumberFormat.currency(
                                                                                              locale: 'vi',
                                                                                              symbol: 'đ',
                                                                                              decimalDigits: 0,
                                                                                            ).format(product.costPrice),
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
                                                                          const SizedBox(height: 20),
                                                                          // Warning text
                                                                          RichText(
                                                                            textAlign: TextAlign.center,
                                                                            text: TextSpan(
                                                                              style: TextStyle(
                                                                                fontSize: 14,
                                                                                color: Colors.grey[700],
                                                                              ),
                                                                              children: [
                                                                                const TextSpan(
                                                                                  text: 'Bạn có chắc chắn muốn xóa ',
                                                                                ),
                                                                                TextSpan(
                                                                                  text: '\"${product.name}\"',
                                                                                  style: const TextStyle(
                                                                                    fontWeight: FontWeight.bold,
                                                                                    color: Colors.red,
                                                                                  ),
                                                                                ),
                                                                                const TextSpan(
                                                                                  text: '? Hành động này không thể hoàn tác.',
                                                                                ),
                                                                              ],
                                                                            ),
                                                                          ),
                                                                          const SizedBox(height: 24),
                                                                          // Action buttons
                                                                          Row(
                                                                            children: [
                                                                              Expanded(
                                                                                child: TextButton(
                                                                                  onPressed: () =>
                                                                                      Navigator.pop(context),
                                                                                  style: TextButton.styleFrom(
                                                                                    padding: const EdgeInsets.symmetric(
                                                                                      vertical: 12,
                                                                                    ),
                                                                                    shape: RoundedRectangleBorder(
                                                                                      borderRadius: BorderRadius.circular(8),
                                                                                      side: const BorderSide(
                                                                                        color: Colors.grey,
                                                                                        width: 1,
                                                                                      ),
                                                                                    ),
                                                                                  ),
                                                                                  child: const Text(
                                                                                    'Hủy',
                                                                                    style: TextStyle(
                                                                                      fontSize: 14,
                                                                                      fontWeight: FontWeight.w600,
                                                                                      color: Colors.grey,
                                                                                    ),
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                              const SizedBox(width: 12),
                                                                              Expanded(
                                                                                child: ElevatedButton(
                                                                                  onPressed: () async {
                                                                                    try {
                                                                                      final success =
                                                                                          await _productService
                                                                                              .hardDeleteProduct(
                                                                                                product.id,
                                                                                              );

                                                                                      if (success) {
                                                                                        final products =
                                                                                            await _productService
                                                                                                .getAllProducts();

                                                                                        if (!mounted) return;

                                                                                        setState(() {
                                                                                          allProducts =
                                                                                              products;
                                                                                          quantities
                                                                                              .remove(
                                                                                                product
                                                                                                    .id,
                                                                                              );
                                                                                          _filterProducts();
                                                                                        });

                                                                                        if (!mounted) return;
                                                                                        Navigator.pop(context);
                                                                                        Navigator.pop(context);

                                                                                        ScaffoldMessenger.of(
                                                                                          context,
                                                                                        ).showSnackBar(
                                                                                          SnackBar(
                                                                                            content: Text(
                                                                                              'Đã xóa "${product.name}"',
                                                                                            ),
                                                                                            backgroundColor:
                                                                                                Colors.green,
                                                                                          ),
                                                                                        );
                                                                                      } else {
                                                                                        if (!mounted) return;
                                                                                        Navigator.pop(context);
                                                                                        ScaffoldMessenger.of(
                                                                                          context,
                                                                                        ).showSnackBar(
                                                                                          const SnackBar(
                                                                                            backgroundColor:
                                                                                                Colors.red,
                                                                                            content: Text(
                                                                                              'Lỗi khi xóa sản phẩm',
                                                                                            ),
                                                                                          ),
                                                                                        );
                                                                                      }
                                                                                    } catch (e) {
                                                                                      if (!mounted) return;
                                                                                      Navigator.pop(context);
                                                                                      ScaffoldMessenger.of(
                                                                                        context,
                                                                                      ).showSnackBar(
                                                                                        SnackBar(
                                                                                          backgroundColor:
                                                                                              Colors.red,
                                                                                          content: Text(
                                                                                            'Lỗi: $e',
                                                                                          ),
                                                                                        ),
                                                                                      );
                                                                                    }
                                                                                  },
                                                                                  style:
                                                                                      ElevatedButton.styleFrom(
                                                                                        backgroundColor:
                                                                                            Colors.red,
                                                                                        foregroundColor:
                                                                                            Colors.white,
                                                                                        padding: const EdgeInsets.symmetric(
                                                                                          vertical: 12,
                                                                                        ),
                                                                                        shape: RoundedRectangleBorder(
                                                                                          borderRadius: BorderRadius.circular(8),
                                                                                        ),
                                                                                      ),
                                                                                  child: const Text(
                                                                                    'Xóa',
                                                                                    style: TextStyle(
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
                          borderRadius: BorderRadius.circular(80),
                        ),
                      ),
                      child: const Icon(Icons.delete, size: 32),
                    ),
                  ],
                ),
              ),
              // Sort buttons section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
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
                          backgroundColor: _sortBy == 'bestselling' ? Colors.blue : Colors.grey[200],
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
                          backgroundColor: _sortBy == 'name' ? const Color.fromARGB(255, 233, 247, 114) : Colors.grey[200],
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
                          backgroundColor: _sortBy == 'price' ? const Color.fromARGB(255, 255, 151, 53) : Colors.grey[200],
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
                                  child: InkWell(
                                    onTap: () {
                                      // Add product to sold items
                                      // SnackBar feedback is handled inside addToSoldItems()
                                      addToSoldItems(product, quantity);
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
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
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
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
                                          // Product Image Placeholder
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
                                            child: const Icon(
                                              Icons.image,
                                              size: 30,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
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
                color: Colors.blue[50],
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
                          const Text(
                            'Đã bán hôm nay',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
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
                                              style: const TextStyle(
                                                fontSize: 15,
                                                color: Colors.black87,
                                              ),
                                            ),
                                            const SizedBox(width: 15),
                                            Text(
                                              timeString,
                                              style: const TextStyle(
                                                fontSize: 15,
                                                color: Colors.black87,
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
                color: Colors.blue[50],
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Đã bán hôm nay: ${soldItems.length}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
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
