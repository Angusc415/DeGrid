import 'package:flutter/material.dart';
import '../../core/geometry/carpet_product.dart';

/// Screen to manage carpet products (name, roll width, optional length/cost) for the current project.
class CarpetProductsScreen extends StatefulWidget {
  final List<CarpetProduct> initialProducts;
  final ValueChanged<List<CarpetProduct>> onProductsChanged;

  const CarpetProductsScreen({
    super.key,
    required this.initialProducts,
    required this.onProductsChanged,
  });

  @override
  State<CarpetProductsScreen> createState() => _CarpetProductsScreenState();
}

class _CarpetProductsScreenState extends State<CarpetProductsScreen> {
  late List<CarpetProduct> _products;

  @override
  void initState() {
    super.initState();
    _products = List<CarpetProduct>.from(widget.initialProducts);
  }

  void _notifyChanged() {
    widget.onProductsChanged(_products);
  }

  Future<void> _addProduct() async {
    final product = await _showProductDialog();
    if (product != null && mounted) {
      setState(() {
        _products.add(product);
        _notifyChanged();
      });
    }
  }

  Future<void> _editProduct(int index) async {
    final product = await _showProductDialog(initial: _products[index]);
    if (product != null && mounted) {
      setState(() {
        _products[index] = product;
        _notifyChanged();
      });
    }
  }

  Future<void> _deleteProduct(int index) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete product?'),
        content: Text(
          'Remove "${_products[index].name}" from carpet products?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      setState(() {
        _products.removeAt(index);
        _notifyChanged();
      });
    }
  }

  Future<CarpetProduct?> _showProductDialog({CarpetProduct? initial}) async {
    final nameController = TextEditingController(text: initial?.name ?? '');
    final widthController = TextEditingController(
      text: initial != null ? initial.rollWidthMm.round().toString() : '4000',
    );
    final lengthController = TextEditingController(
      text: initial?.rollLengthM?.toString() ?? '',
    );
    final costController = TextEditingController(
      text: initial?.costPerSqm?.toString() ?? '',
    );

    return showDialog<CarpetProduct>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(initial == null ? 'Add carpet product' : 'Edit carpet product'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'e.g. Standard 4m',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: widthController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Roll width (mm)',
                  hintText: 'e.g. 4000',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: lengthController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Roll length (m) – optional',
                  hintText: 'e.g. 25',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: costController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Cost per m² – optional',
                  hintText: 'e.g. 35.00',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              final widthMm = double.tryParse(widthController.text.trim());
              if (widthMm == null || widthMm <= 0) return;
              final lengthM = double.tryParse(lengthController.text.trim());
              final costPerSqm = double.tryParse(costController.text.trim());
              Navigator.pop(
                context,
                CarpetProduct(
                  name: name,
                  rollWidthMm: widthMm,
                  rollLengthM: lengthM?.isFinite == true ? lengthM : null,
                  costPerSqm: costPerSqm != null && costPerSqm.isFinite ? costPerSqm : null,
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Carpet products'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _products.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.layers,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No carpet products yet',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add products with roll width (mm) to use for carpet planning in rooms.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _products.length,
              itemBuilder: (context, index) {
                final p = _products[index];
                return ListTile(
                  leading: CircleAvatar(
                    child: Icon(Icons.layers, color: Theme.of(context).colorScheme.onPrimary),
                  ),
                  title: Text(p.name),
                  subtitle: Text(
                    '${p.rollWidthMm.round()} mm wide'
                    '${p.rollLengthM != null ? ' · ${p.rollLengthM} m roll' : ''}'
                    '${p.costPerSqm != null ? ' · ${p.costPerSqm!.toStringAsFixed(2)}/m²' : ''}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _editProduct(index),
                        tooltip: 'Edit',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _deleteProduct(index),
                        tooltip: 'Delete',
                      ),
                    ],
                  ),
                  onTap: () => _editProduct(index),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addProduct,
        tooltip: 'Add carpet product',
        child: const Icon(Icons.add),
      ),
    );
  }
}
