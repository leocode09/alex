import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../models/product.dart';
import '../../../providers/product_provider.dart';

class AddEditProductPage extends ConsumerStatefulWidget {
  final String? productId;
  final String? initialName;

  const AddEditProductPage({
    super.key,
    this.productId,
    this.initialName,
  });

  @override
  ConsumerState<AddEditProductPage> createState() => _AddEditProductPageState();
}

class _AddEditProductPageState extends ConsumerState<AddEditProductPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _costPriceController = TextEditingController();
  final _stockController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _supplierController = TextEditingController();
  final _discountPercentageController = TextEditingController();
  final _discountAmountController = TextEditingController();

  String? _selectedCategory;
  bool _isLoading = false;

  bool get isEditing => widget.productId != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _loadProductData();
    } else if (widget.initialName != null && widget.initialName!.isNotEmpty) {
      _nameController.text = widget.initialName!;
    }
  }

  Future<void> _loadProductData() async {
    final product = await ref
        .read(productRepositoryProvider)
        .getProductById(widget.productId!);

    if (product != null) {
      setState(() {
        _nameController.text = product.name;
        _priceController.text = product.price.toStringAsFixed(0);
        _costPriceController.text = product.costPrice?.toStringAsFixed(0) ?? '';
        _stockController.text = product.stock.toString();
        _barcodeController.text = product.barcode ?? '';
        _selectedCategory = product.category;
        _supplierController.text = product.supplier ?? '';
        _discountPercentageController.text = product.discountPercentage?.toStringAsFixed(0) ?? '';
        _discountAmountController.text = product.discountAmount?.toStringAsFixed(0) ?? '';
      });
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_barcodeController.text.isNotEmpty) {
      final barcodeExists = await ref
          .read(productNotifierProvider.notifier)
          .barcodeExists(
            _barcodeController.text,
            excludeId: widget.productId,
          );

      if (barcodeExists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('A product with this barcode already exists'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final product = Product(
        id: widget.productId ?? const Uuid().v4(),
        name: _nameController.text.trim(),
        price: double.parse(_priceController.text),
        stock: int.parse(_stockController.text),
        category: _selectedCategory,
        barcode: _barcodeController.text.isEmpty ? null : _barcodeController.text,
        costPrice: _costPriceController.text.isEmpty
            ? null
            : double.parse(_costPriceController.text),
        supplier: _supplierController.text.isEmpty ? null : _supplierController.text,
        discountPercentage: _discountPercentageController.text.isEmpty
            ? null
            : double.parse(_discountPercentageController.text),
        discountAmount: _discountAmountController.text.isEmpty
            ? null
            : double.parse(_discountAmountController.text),
        sku: '', // Assuming SKU is generated or optional
      );

      if (isEditing) {
        await ref.read(productNotifierProvider.notifier).updateProduct(product);
      } else {
        await ref.read(productNotifierProvider.notifier).addProduct(product);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing ? 'Product updated' : 'Product added'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Product' : 'Add Product', style: const TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveProduct,
            child: _isLoading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSectionTitle('Basic Info'),
            _buildTextField(
              controller: _nameController,
              label: 'Product Name',
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _priceController,
                    label: 'Selling Price',
                    keyboardType: TextInputType.number,
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    controller: _stockController,
                    label: 'Stock',
                    keyboardType: TextInputType.number,
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            _buildSectionTitle('Category'),
            categoriesAsync.when(
              data: (categories) => DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                ),
                items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => _selectedCategory = v),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const Text('Error loading categories'),
            ),
            const SizedBox(height: 24),

            _buildSectionTitle('Additional Details'),
            _buildTextField(
              controller: _barcodeController,
              label: 'Barcode (Optional)',
              suffixIcon: IconButton(
                icon: const Icon(Icons.qr_code_scanner),
                onPressed: () {
                  // TODO: Implement scanner
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _costPriceController,
                    label: 'Cost Price',
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    controller: _supplierController,
                    label: 'Supplier',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            _buildSectionTitle('Discounts (Optional)'),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _discountPercentageController,
                    label: 'Discount %',
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v != null && v.isNotEmpty) {
                        final value = double.tryParse(v);
                        if (value == null || value < 0 || value > 100) {
                          return 'Must be 0-100';
                        }
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    controller: _discountAmountController,
                    label: 'Discount Amount',
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v != null && v.isNotEmpty) {
                        final value = double.tryParse(v);
                        if (value == null || value < 0) {
                          return 'Must be ≥ 0';
                        }
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Note: Both percentage and fixed amount discounts can be applied. Percentage is calculated first.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        suffixIcon: suffixIcon,
      ),
    );
  }
}
