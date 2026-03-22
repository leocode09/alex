import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../models/product.dart';
import '../../../providers/product_provider.dart';
import '../../../helpers/pin_protection.dart';
import '../../../services/pin_service.dart';

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

  String? _selectedCategory;
  List<ProductPackage> _packages = [];
  int _computedLoose = 0;
  bool _isLoading = false;
  bool _pinVerified = false;

  bool get isEditing => widget.productId != null;

  @override
  void initState() {
    super.initState();
    _checkPinAndLoadData();
  }

  void _onStockChanged(String _) {
    if (_hasPackages) {
      setState(() {
        _autoDistribute();
      });
    }
  }

  /// Bottom-up: recalculate total units from manual package counts,
  /// then update the stock field (onChanged won't fire for programmatic sets).
  void _recomputeTotalFromPackages() {
    final inPackages = _packages.fold<int>(
      0,
      (sum, p) => sum + p.packageCount * p.unitsPerPackage,
    );
    final total = inPackages + _computedLoose;
    _stockController.text = '$total';
  }

  Future<void> _checkPinAndLoadData() async {
    // Check if PIN is required for this action
    final pinService = PinService();
    final requirePin = isEditing
        ? await pinService.isPinRequiredForEditProduct()
        : await pinService.isPinRequiredForAddProduct();

    if (requirePin) {
      final pinValid = await PinProtection.requirePin(
        context,
        title: isEditing ? 'Edit Product' : 'Add Product',
        subtitle: 'Enter PIN to ${isEditing ? 'edit' : 'add'} product',
      );

      if (!pinValid) {
        if (mounted) {
          Navigator.of(context).pop();
        }
        return;
      }
    }

    setState(() {
      _pinVerified = true;
    });

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
        _priceController.text =
            product.price > 0 ? product.price.toString() : '';
        _costPriceController.text = product.costPrice?.toString() ?? '';
        _stockController.text = product.stock.toString();
        _barcodeController.text = product.barcode ?? '';
        _selectedCategory = product.category;
        _supplierController.text = product.supplier ?? '';
        _packages = List.from(product.packages);
        _autoDistribute();
      });
    }
  }

  bool get _hasPackages => _packages.isNotEmpty;

  /// Independently calculates how many of each package the total stock
  /// can yield: each package gets floor(total / unitsPerPackage).
  void _autoDistribute() {
    final total = int.tryParse(_stockController.text.trim()) ?? 0;
    if (!_hasPackages || total <= 0) {
      _computedLoose = total.clamp(0, 1 << 30);
      _packages = _packages.map((p) => p.copyWith(packageCount: 0)).toList();
      return;
    }

    _computedLoose = 0;
    _packages = [
      for (final p in _packages)
        p.copyWith(
          packageCount:
              p.unitsPerPackage > 0 ? total ~/ p.unitsPerPackage : 0,
        ),
    ];
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final unitPrice = double.tryParse(_priceController.text.trim());
    if (_hasPackages) {
      final needsUnitOrFixed = unitPrice == null || unitPrice <= 0;
      if (needsUnitOrFixed) {
        for (final p in _packages) {
          if (p.packagePrice == null) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Enter a unit price, or set a fixed price on every package.',
                  ),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return;
          }
        }
      }
    }

    if (_barcodeController.text.isNotEmpty) {
      final barcodeExists =
          await ref.read(productNotifierProvider.notifier).barcodeExists(
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
      final totalStock = int.tryParse(_stockController.text.trim()) ?? 0;

      final parsedSelling = double.tryParse(_priceController.text.trim());
      final sellingPrice = _hasPackages
          ? (parsedSelling != null && parsedSelling > 0 ? parsedSelling : 0.0)
          : (parsedSelling ?? 0);

      final product = Product(
        id: widget.productId ?? const Uuid().v4(),
        name: _nameController.text.trim(),
        price: sellingPrice,
        stock: totalStock,
        looseStock: _computedLoose,
        category: _selectedCategory,
        barcode:
            _barcodeController.text.isEmpty ? null : _barcodeController.text,
        costPrice: _costPriceController.text.isEmpty
            ? null
            : double.parse(_costPriceController.text),
        supplier:
            _supplierController.text.isEmpty ? null : _supplierController.text,
        sku: '',
        packages: _packages,
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
    // Show loading while verifying PIN
    if (!_pinVerified) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Product' : 'Add Product',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveProduct,
            child: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save',
                    style: TextStyle(fontWeight: FontWeight.bold)),
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
            const SizedBox(height: 24),
            _buildPackagesSection(context),
            const SizedBox(height: 24),
            _buildSectionTitle('Pricing & Stock'),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _priceController,
                    label: _hasPackages
                        ? 'Unit price (optional)'
                        : 'Selling Price',
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (!_hasPackages) {
                        if (v == null || v.isEmpty) return 'Required';
                        final value = double.tryParse(v);
                        if (value == null || value <= 0) {
                          return 'Enter a valid price';
                        }
                        return null;
                      }
                      if (v == null || v.isEmpty) return null;
                      final value = double.tryParse(v);
                      if (value == null || value < 0) {
                        return 'Enter a valid price';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    controller: _stockController,
                    label: 'Total units in stock',
                    keyboardType: TextInputType.number,
                    onChanged: _onStockChanged,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      final value = int.tryParse(v);
                      if (value == null || value < 0) {
                        return 'Enter a valid stock';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            if (_hasPackages) ...[
              const SizedBox(height: 12),
              _buildDistributionDashboard(context),
            ],
            const SizedBox(height: 24),
            _buildSectionTitle('Category'),
            categoriesAsync.when(
              data: (categories) => DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                ),
                items: categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
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
                onPressed: () async {
                  final allowed = await PinProtection.requirePinIfNeeded(
                    context,
                    isRequired: () =>
                        PinService().isPinRequiredForScanBarcode(),
                    title: 'Scan Barcode',
                    subtitle: 'Enter PIN to scan barcode',
                  );
                  if (!allowed) {
                    return;
                  }
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
                    validator: (v) {
                      if (v == null || v.isEmpty) return null;
                      final value = double.tryParse(v);
                      if (value == null || value < 0) {
                        return 'Enter a valid cost';
                      }
                      return null;
                    },
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
          ],
        ),
      ),
    );
  }

  Widget _buildPackagesSection(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Packages (optional)',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Define alternate sell units. Package counts follow total stock unless you enter counts manually.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            if (_packages.isEmpty)
              _buildPackagesEmptyState(context)
            else
              ..._packages.asMap().entries.map((e) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildPackageTile(
                    context,
                    package: e.value,
                    index: e.key,
                  ),
                );
              }),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: () => _showPackageEditorDialog(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add package'),
              style: OutlinedButton.styleFrom(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPackagesEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
        child: Text(
          'No packages defined. Add one to sell by case, bundle, or other unit.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: cs.onSurfaceVariant,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildPackageTile(
    BuildContext context, {
    required ProductPackage package,
    required int index,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final sell = _packageSellPrice(package);
    final cost = package.packageCostPrice;
    final margin = (cost != null && sell != null) ? (sell - cost) : null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showPackageEditorDialog(existing: package),
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          decoration: BoxDecoration(
            color: index.isEven ? cs.surface : cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              package.name,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${package.unitsPerPackage} units / pkg',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _buildPackagePricingRichText(
                        context,
                        sell: sell,
                        cost: cost,
                        margin: margin,
                      ),
                    ],
                  ),
                ),
                if (_hasPackages && package.packageCount > 0) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 52,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${package.packageCount}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'in stock',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.delete_outline, color: cs.onSurfaceVariant),
                  tooltip: 'Remove',
                  onPressed: () {
                    final hadManualCounts = _packages.any(
                      (pkg) => pkg.packageCount > 0 && pkg.id != package.id,
                    );
                    setState(() {
                      _packages.removeWhere((x) => x.id == package.id);
                      if (hadManualCounts) {
                        _recomputeTotalFromPackages();
                      } else {
                        _autoDistribute();
                      }
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPackagePricingRichText(
    BuildContext context, {
    required double? sell,
    required double? cost,
    required double? margin,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final baseStyle = theme.textTheme.bodySmall?.copyWith(
      color: cs.onSurfaceVariant,
      height: 1.35,
    );
    final spans = <InlineSpan>[
      TextSpan(
        text: sell != null ? 'Sell \$${sell.toStringAsFixed(2)}' : 'Sell —',
        style: baseStyle,
      ),
    ];
    if (cost != null) {
      spans.add(TextSpan(text: ' · ', style: baseStyle));
      spans.add(TextSpan(
        text: 'Cost \$${cost.toStringAsFixed(2)}',
        style: baseStyle,
      ));
    }
    if (margin != null) {
      spans.add(TextSpan(text: ' · Margin ', style: baseStyle));
      spans.add(TextSpan(
        text: '\$${margin.toStringAsFixed(2)}',
        style: baseStyle?.copyWith(
          color: margin < 0 ? cs.error : cs.onSurface,
          fontWeight: FontWeight.w500,
        ),
      ));
    }
    return Text.rich(TextSpan(children: spans));
  }

  double? _packageSellPrice(ProductPackage p) {
    final unit = _draftUnitPrice;
    if (unit != null && unit > 0) {
      return sellingPriceForPackage(unitPrice: unit, pkg: p);
    }
    return p.packagePrice;
  }

  Widget _buildDistributionDashboard(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final total = int.tryParse(_stockController.text.trim()) ?? 0;

    if (total <= 0) {
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: cs.surfaceContainerLow,
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Text(
            'Enter total units in stock to see how many full packages of each size that quantity represents.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: cs.surfaceContainerLow,
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Distribution preview',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '$total units',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Each line is independent: full packages of that size that fit in the total.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            ..._packages.asMap().entries.map((e) {
              final p = e.value;
              final i = e.key;
              final u = p.unitsPerPackage;
              final pkgsFromTotal = u > 0 ? total ~/ u : 0;
              final remainderForPackSize = u > 0 ? total % u : total;
              final rowBg =
                  i.isEven ? cs.surface : cs.surfaceContainerHighest;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: rowBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.name,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$pkgsFromTotal × $u units'
                                '${remainderForPackSize > 0 ? ' · $remainderForPackSize remainder' : ''}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '$pkgsFromTotal',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  double? get _draftUnitPrice =>
      double.tryParse(_priceController.text.trim());

  Future<void> _showPackageEditorDialog({ProductPackage? existing}) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final unitsController = TextEditingController(
      text: existing != null ? '${existing.unitsPerPackage}' : '',
    );
    final packagePriceController = TextEditingController(
      text: existing?.packagePrice?.toString() ?? '',
    );
    final packageCostPriceController = TextEditingController(
      text: existing?.packageCostPrice?.toString() ?? '',
    );
    final packageCountController = TextEditingController(
      text: existing != null ? '${existing.packageCount}' : '0',
    );
    final isEdit = existing != null;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? 'Edit Package' : 'Add Package'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Package name (e.g. 1/4 pack, Half pack)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: unitsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Units per package',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: packagePriceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Selling price (optional)',
                  helperText: 'Leave empty = unit price × units',
                  prefixText: '\$ ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: packageCostPriceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Cost price (optional)',
                  helperText: 'What you pay for this package',
                  prefixText: '\$ ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: packageCountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Number of packages (optional)',
                  helperText: 'Total units will be recalculated',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final units = int.tryParse(unitsController.text.trim());
              if (name.isEmpty || units == null || units < 1) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Enter a valid name and units (≥ 1)'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              final priceRaw = packagePriceController.text.trim();
              double? pkgPrice;
              if (priceRaw.isNotEmpty) {
                pkgPrice = double.tryParse(priceRaw);
                if (pkgPrice == null || pkgPrice <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Enter a valid package price or leave empty'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
              }
              final costRaw = packageCostPriceController.text.trim();
              double? pkgCostPrice;
              if (costRaw.isNotEmpty) {
                pkgCostPrice = double.tryParse(costRaw);
                if (pkgCostPrice == null || pkgCostPrice < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Enter a valid cost price or leave empty'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
              }
              final pkgCount = int.tryParse(
                packageCountController.text.trim(),
              );
              if (pkgCount != null && pkgCount < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Package count cannot be negative'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              final hasManualCount = pkgCount != null && pkgCount > 0;
              final existingId = existing?.id;
              setState(() {
                final pkg = ProductPackage(
                  id: existingId ?? const Uuid().v4(),
                  name: name,
                  unitsPerPackage: units,
                  packagePrice: pkgPrice,
                  packageCostPrice: pkgCostPrice,
                  packageCount: hasManualCount ? pkgCount : 0,
                );
                if (isEdit && existingId != null) {
                  final i = _packages.indexWhere((x) => x.id == existingId);
                  if (i >= 0) {
                    _packages[i] = pkg;
                  }
                } else {
                  _packages.add(pkg);
                }
                if (hasManualCount) {
                  _recomputeTotalFromPackages();
                } else {
                  _autoDistribute();
                }
              });
              Navigator.pop(ctx);
            },
            child: Text(isEdit ? 'Save' : 'Add'),
          ),
        ],
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
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        suffixIcon: suffixIcon,
      ),
    );
  }
}
