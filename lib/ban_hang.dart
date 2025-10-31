import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
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

  late List<Product> allProducts;
  late List<Product> filteredProducts;
  late List<SoldItem> soldItems;

  final Map<int, int> quantities = {};

  @override
  void initState() {
    super.initState();
    allProducts = [];
    filteredProducts = [];
    soldItems = [];
    _initializeData();
    searchController.addListener(_filterProducts);
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
    setState(() {
      filteredProducts = allProducts
          .where((product) => product.name.toLowerCase().contains(query))
          .toList();
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
            return AlertDialog(
              title: const Text('Thêm mặt hàng mới'),
              content: SingleChildScrollView(
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
                                    'Chọn ảnh mặt hàng',
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
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Tên sản phẩm',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: priceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Giá bán (VND)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: costPriceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Giá vốn (VND)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: quantityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Số lượng hàng',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: unitController,
                      decoration: const InputDecoration(
                        labelText: 'Đơn vị (cái, kg, ly, hộp, v.v.)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      if (nameController.text.isEmpty ||
                          priceController.text.isEmpty ||
                          costPriceController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Vui lòng điền đầy đủ thông tin'),
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
                          ),
                        );
                        return;
                      }

                      await _productService.addProduct(
                        name,
                        price,
                        costPrice,
                        unit: unit,
                      );

                      if (!mounted) return;
                      Navigator.pop(context);

                      // If quantity > 0, we need to update it after creation
                      if (quantity > 0) {
                        final products = await _productService.getAllProducts();
                        final newProduct = products.lastWhere(
                          (p) => p.name == name,
                          orElse: () => throw Exception('Product not found'),
                        );
                        await _productService.updateProduct(
                          newProduct.copyWith(stock: quantity),
                        );
                      }

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
                      ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.blue,
                  ),
                  child: const Text('Thêm'),
                ),
              ],
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
                        // Show list of products to delete
                        showDialog(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              title: const Text('Xóa Mặt Hàng'),
                              content: SizedBox(
                                width: double.maxFinite,
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  itemCount: allProducts.length,
                                  separatorBuilder: (context, index) =>
                                      const Divider(
                                        height: 1,
                                        thickness: 1,
                                        color: Colors.black,
                                      ),
                                  itemBuilder: (context, index) {
                                    final product = allProducts[index];
                                    return ListTile(
                                      title: Text(product.name),
                                      subtitle: Text('${product.price} VND'),
                                      trailing: IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                        ),
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder: (context) {
                                              return AlertDialog(
                                                title: const Text(
                                                  'Xác nhận xóa',
                                                ),
                                                content: Text(
                                                  'Bạn có chắc chắn muốn xóa "${product.name}"?',
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(context),
                                                    child: const Text('Hủy'),
                                                  ),
                                                  ElevatedButton(
                                                    onPressed: () async {
                                                      // Delete product from database
                                                      final success =
                                                          await _productService
                                                              .hardDeleteProduct(
                                                                product.id,
                                                              );

                                                      if (success) {
                                                        // Reload products from database
                                                        final products =
                                                            await _productService
                                                                .getAllProducts();

                                                        // Check if widget is still mounted
                                                        if (!mounted) return;

                                                        setState(() {
                                                          allProducts =
                                                              products;
                                                          quantities.remove(
                                                            product.id,
                                                          );
                                                          _filterProducts();
                                                        });

                                                        Navigator.pop(
                                                          context,
                                                        ); // Close confirmation dialog
                                                        Navigator.pop(
                                                          context,
                                                        ); // Close product list dialog

                                                        ScaffoldMessenger.of(
                                                          context,
                                                        ).showSnackBar(
                                                          SnackBar(
                                                            content: Text(
                                                              'Đã xóa "${product.name}"',
                                                            ),
                                                          ),
                                                        );
                                                      } else {
                                                        // Check if widget is still mounted
                                                        if (!mounted) return;

                                                        Navigator.pop(context);
                                                        ScaffoldMessenger.of(
                                                          context,
                                                        ).showSnackBar(
                                                          const SnackBar(
                                                            backgroundColor:
                                                                Colors.red,
                                                            content: Text(
                                                              'Lỗi khi xóa mặt hàng',
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
                                                        ),
                                                    child: const Text('Xóa'),
                                                  ),
                                                ],
                                              );
                                            },
                                          );
                                        },
                                      ),
                                    );
                                  },
                                ),
                              ),
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
                                                    content: TextField(
                                                      controller: controller,
                                                      keyboardType:
                                                          TextInputType.number,
                                                      autofocus: true,
                                                      decoration:
                                                          const InputDecoration(
                                                            labelText:
                                                                'Số lượng',
                                                            border:
                                                                OutlineInputBorder(),
                                                          ),
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
