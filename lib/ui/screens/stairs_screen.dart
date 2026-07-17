import 'package:flutter/material.dart';
import '../../core/geometry/carpet_product.dart';
import '../../core/quote/staircase.dart';

/// Screen to manage carpeted staircases for the current project. Each flight
/// captures steps and dimensions and optionally ties to a carpet product for
/// pricing on the job quote.
class StairsScreen extends StatefulWidget {
  final List<Staircase> initialStaircases;
  final List<CarpetProduct> carpetProducts;
  final ValueChanged<List<Staircase>> onStaircasesChanged;

  const StairsScreen({
    super.key,
    required this.initialStaircases,
    required this.carpetProducts,
    required this.onStaircasesChanged,
  });

  @override
  State<StairsScreen> createState() => _StairsScreenState();
}

class _StairsScreenState extends State<StairsScreen> {
  late List<Staircase> _stairs;

  @override
  void initState() {
    super.initState();
    _stairs = List<Staircase>.from(widget.initialStaircases);
  }

  void _notifyChanged() => widget.onStaircasesChanged(_stairs);

  Future<void> _add() async {
    final s = await _showStairDialog();
    if (s != null && mounted) {
      setState(() {
        _stairs.add(s);
        _notifyChanged();
      });
    }
  }

  Future<void> _edit(int index) async {
    final s = await _showStairDialog(initial: _stairs[index]);
    if (s != null && mounted) {
      setState(() {
        _stairs[index] = s;
        _notifyChanged();
      });
    }
  }

  Future<void> _delete(int index) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete staircase?'),
        content: Text('Remove "${_stairs[index].name}"?'),
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
        _stairs.removeAt(index);
        _notifyChanged();
      });
    }
  }

  Future<Staircase?> _showStairDialog({Staircase? initial}) async {
    final base = initial ?? const Staircase(name: 'Stairs');
    final nameCtrl = TextEditingController(text: base.name);
    final stepsCtrl = TextEditingController(text: base.steps.toString());
    final goingCtrl = TextEditingController(text: base.goingMm.round().toString());
    final riserCtrl = TextEditingController(text: base.riserMm.round().toString());
    final widthCtrl = TextEditingController(text: base.widthMm.round().toString());
    final nosingCtrl = TextEditingController(text: base.nosingMm.round().toString());
    int? productIndex = base.carpetProductIndex != null &&
            base.carpetProductIndex! >= 0 &&
            base.carpetProductIndex! < widget.carpetProducts.length
        ? base.carpetProductIndex
        : null;

    Widget numField(TextEditingController c, String label) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            controller: c,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
            ),
          ),
        );

    return showDialog<Staircase>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(initial == null ? 'Add staircase' : 'Edit staircase'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      hintText: 'e.g. Main stairs',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                numField(stepsCtrl, 'Number of steps'),
                numField(goingCtrl, 'Tread depth / going (mm)'),
                numField(riserCtrl, 'Riser height (mm)'),
                numField(widthCtrl, 'Stair width (mm)'),
                numField(nosingCtrl, 'Nosing wrap per step (mm)'),
                DropdownButtonFormField<int?>(
                  initialValue: productIndex,
                  decoration: const InputDecoration(
                    labelText: 'Carpet product',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('None (unpriced)'),
                    ),
                    for (var i = 0; i < widget.carpetProducts.length; i++)
                      DropdownMenuItem<int?>(
                        value: i,
                        child: Text(widget.carpetProducts[i].name),
                      ),
                  ],
                  onChanged: (v) => setLocal(() => productIndex = v),
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
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                final steps = int.tryParse(stepsCtrl.text.trim());
                if (steps == null || steps <= 0) return;
                double parse(TextEditingController c, double fallback) =>
                    double.tryParse(c.text.trim()) ?? fallback;
                Navigator.pop(
                  context,
                  Staircase(
                    name: name,
                    steps: steps,
                    goingMm: parse(goingCtrl, base.goingMm),
                    riserMm: parse(riserCtrl, base.riserMm),
                    widthMm: parse(widthCtrl, base.widthMm),
                    nosingMm: parse(nosingCtrl, base.nosingMm),
                    carpetProductIndex: productIndex,
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stairs'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('Add staircase'),
      ),
      body: _stairs.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No staircases yet.\nAdd a flight to include it in the job quote.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).hintColor,
                      ),
                ),
              ),
            )
          : ListView.builder(
              itemCount: _stairs.length,
              itemBuilder: (context, i) {
                final s = _stairs[i];
                final product = s.carpetProductIndex != null &&
                        s.carpetProductIndex! >= 0 &&
                        s.carpetProductIndex! < widget.carpetProducts.length
                    ? widget.carpetProducts[s.carpetProductIndex!].name
                    : 'No product';
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Icon(Icons.stairs,
                        color: Theme.of(context).colorScheme.onPrimary),
                  ),
                  title: Text(s.name),
                  subtitle: Text(
                    '${s.steps} steps · ${s.widthMm.round()} mm wide · '
                    '${s.carpetAreaSqm.toStringAsFixed(2)} m² · $product',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _edit(i),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _delete(i),
                      ),
                    ],
                  ),
                  onTap: () => _edit(i),
                );
              },
            ),
    );
  }
}
