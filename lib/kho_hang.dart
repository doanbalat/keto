import 'package:flutter/material.dart';
import 'dart:io';
import 'models/product_model.dart';
import 'services/product_service.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final ProductService _productService = ProductService();
  final TextEditingController _searchController = TextEditingController();

  List<Product> allProducts = [];
  List<Product> filteredProducts = [];

  bool _isLoading = true;
  String? _activeFilter; // Track active filter: 'all', 'inStock', 'outOfStock', 'lowStock'

  @override
  void initState() {
    super.initState();
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
      filteredProducts = allProducts
          .where((product) {
            // First check search query
            final matchesSearch = product.name.toLowerCase().contains(query);
            if (!matchesSearch) return false;
            
            // Then apply active filter
            if (_activeFilter == null || _activeFilter == 'all') {
              return true;
            } else if (_activeFilter == 'inStock') {
              return product.stock > 0;
            } else if (_activeFilter == 'outOfStock') {
              return product.stock == 0;
            } else if (_activeFilter == 'lowStock') {
              return product.stock > 0 && product.stock <= 5;
            }
            return true;
          })
          .toList();
    });
  }

  Color _getStockIndicatorColor(int quantity) {
    if (quantity == 0) return Colors.red;
    if (quantity < 5) return Colors.orange;
    return Colors.green;
  }

  String _getStockStatus(int quantity) {
    if (quantity == 0) return 'Hết hàng';
    if (quantity < 5) return 'Sắp hết';
    return 'Còn hàng';
  }

  int _getTotalInventoryValue() {
    return allProducts.fold<int>(
      0,
      (sum, product) => sum + (product.stock * product.price),
    );
  }

  int _getProductsInStock() {
    return allProducts.where((p) => p.stock > 0).length;
  }

  int _getProductsOutOfStock() {
    return allProducts.where((p) => p.stock == 0).length;
  }

  int _getLowStockProducts() {
    return allProducts.where((p) => p.stock > 0 && p.stock <= 5).length;
  }

  void _showAdjustStockDialog(Product product) {
    final quantityController = TextEditingController(
      text: product.stock.toString(),
    );
    int currentValue = product.stock;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final difference = currentValue - product.stock;
            final isIncreasing = difference > 0;
            
            return AlertDialog(
              title: Text('Cập nhật kho - ${product.name}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                            'Kho hiện tại:',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
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
                      'Điều chỉnh nhanh:',
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
                              currentValue = (currentValue - 10).clamp(0, 999999);
                              quantityController.text = currentValue.toString();
                            }),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[100],
                              foregroundColor: Colors.red,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            child: const Text('-10', style: TextStyle(fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => setDialogState(() {
                              currentValue = (currentValue - 1).clamp(0, 999999);
                              quantityController.text = currentValue.toString();
                            }),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[100],
                              foregroundColor: Colors.red,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            child: const Text('-1', style: TextStyle(fontSize: 12)),
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
                              foregroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            child: const Text('+1', style: TextStyle(fontSize: 12)),
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
                              foregroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            child: const Text('+10', style: TextStyle(fontSize: 12)),
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
                        labelText: 'Nhập số lượng mới',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        suffixText: product.unit,
                        counterText: difference == 0
                            ? 'Không thay đổi'
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
                    const SizedBox(height: 16),

                    // Price info
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Giá bán:',
                                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                              ),
                              Text(
                                NumberFormat.currency(
                                  locale: 'vi',
                                  symbol: 'đ',
                                  decimalDigits: 0,
                                ).format(product.price),
                                style: const TextStyle(
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
                                'Giá vốn:',
                                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                              ),
                              Text(
                                NumberFormat.currency(
                                  locale: 'vi',
                                  symbol: 'đ',
                                  decimalDigits: 0,
                                ).format(product.costPrice),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Divider(height: 12, color: Colors.orange[200]),
                          Text(
                            'Giá trị kho hiện tại: ${NumberFormat.currency(locale: 'vi', symbol: 'đ', decimalDigits: 0).format(product.stock * product.price)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
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
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      final newQuantity = int.parse(quantityController.text);
                      if (newQuantity < 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Số lượng không được âm')),
                        );
                        return;
                      }

                      final updatedProduct = product.copyWith(stock: newQuantity);
                      await _productService.updateProduct(updatedProduct);

                      if (!mounted) return;
                      Navigator.pop(context);

                      await _loadProducts();

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Cập nhật kho cho "${product.name}" thành công',
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  child: const Text('Cập nhật'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddProductDialog() {
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

                      await _loadProducts();

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
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange, Colors.white],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tóm tắt kho hàng',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _activeFilter = _activeFilter == 'all' ? null : 'all';
                              _filterProducts();
                            });
                          },
                          child: _buildStatItem(
                            value: allProducts.length.toString(),
                            label: 'Tổng',
                            color: Colors.blue,
                            icon: Icons.inventory_2,
                            isActive: _activeFilter == 'all' || _activeFilter == null,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _activeFilter = _activeFilter == 'inStock' ? null : 'inStock';
                              _filterProducts();
                            });
                          },
                          child: _buildStatItem(
                            value: _getProductsInStock().toString(),
                            label: 'Còn hàng',
                            color: Colors.green,
                            icon: Icons.check_circle,
                            isActive: _activeFilter == 'inStock',
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _activeFilter = _activeFilter == 'lowStock' ? null : 'lowStock';
                              _filterProducts();
                            });
                          },
                          child: _buildStatItem(
                            value: _getLowStockProducts().toString(),
                            label: 'Sắp hết',
                            color: Colors.orange,
                            icon: Icons.warning,
                            isActive: _activeFilter == 'lowStock',
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _activeFilter = _activeFilter == 'outOfStock' ? null : 'outOfStock';
                              _filterProducts();
                            });
                          },
                          child: _buildStatItem(
                            value: _getProductsOutOfStock().toString(),
                            label: 'Hết hàng',
                            color: Colors.red,
                            icon: Icons.cancel,
                            isActive: _activeFilter == 'outOfStock',
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _activeFilter = _activeFilter == 'value' ? null : 'value';
                              _filterProducts();
                            });
                          },
                          child: _buildStatItem(
                            value:
                                '${(_getTotalInventoryValue() / 1000000).toStringAsFixed(1)}M',
                            label: 'Giá trị kho',
                            color: Colors.purple,
                            icon: Icons.monetization_on,
                            isActive: false,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Search and Action Buttons
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  // Search TextField
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Tìm sản phẩm...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Colors.grey,
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Colors.blue,
                            width: 2,
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
                    onPressed: _showAddProductDialog,
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
                  const SizedBox(width: 8),
                  // Delete Product Button
                  ElevatedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            title: const Text('Xóa Sản Phẩm'),
                            content: SizedBox(
                              width: double.maxFinite,
                              child: ListView.separated(
                                shrinkWrap: true,
                                itemCount: allProducts.length,
                                separatorBuilder: (context, index) =>
                                    const Divider(
                                      height: 1,
                                      thickness: 1,
                                      color: Colors.grey,
                                    ),
                                itemBuilder: (context, index) {
                                  final product = allProducts[index];
                                  return ListTile(
                                    title: Text(product.name),
                                    subtitle: Text(
                                      '${product.stock} ${product.unit} - ${NumberFormat.currency(locale: 'vi', symbol: 'đ', decimalDigits: 0).format(product.price)}',
                                    ),
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
                                              title: const Text('Xác nhận xóa'),
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
                        borderRadius: BorderRadius.circular(50),
                      ),
                    ),
                    child: const Icon(Icons.delete, size: 32),
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
                                ? 'Chưa có sản phẩm nào'
                                : 'Không tìm thấy sản phẩm',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: filteredProducts.length,
                      itemBuilder: (context, index) {
                        final product = filteredProducts[index];
                        final stockColor = _getStockIndicatorColor(
                          product.stock,
                        );
                        final stockStatus = _getStockStatus(product.stock);

                        return Card(
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                                'Giá: ${NumberFormat.currency(locale: 'vi', symbol: 'đ', decimalDigits: 0).format(product.price)}',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.grey[700],
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              child: Text(
                                                'Vốn: ${NumberFormat.currency(locale: 'vi', symbol: 'đ', decimalDigits: 0).format(product.costPrice)}',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.grey[700],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: stockColor.withValues(
                                                  alpha: 0.2,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(4),
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
                                          fontSize: 12,
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
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isActive ? color : color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isActive ? color : Colors.grey[700],
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
