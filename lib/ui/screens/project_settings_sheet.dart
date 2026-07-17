import 'package:flutter/material.dart';

import '../../core/quote/quote_rates.dart';

/// Simple per-project settings sheet.
class ProjectSettingsSheet extends StatefulWidget {
  final double initialWallWidthMm;
  final ValueChanged<double> onWallWidthChanged;
  final double? initialDoorThicknessMm;
  final ValueChanged<double?>? onDoorThicknessChanged;
  final bool initialUseImperial;
  final bool initialShowGrid;
  final ValueChanged<bool> onUseImperialChanged;
  final ValueChanged<bool> onShowGridChanged;

  /// Quote pricing rates; section hidden when [onQuoteRatesChanged] is null.
  final QuoteRates initialQuoteRates;
  final ValueChanged<QuoteRates>? onQuoteRatesChanged;

  const ProjectSettingsSheet({
    super.key,
    required this.initialWallWidthMm,
    required this.onWallWidthChanged,
    this.initialDoorThicknessMm,
    this.onDoorThicknessChanged,
    required this.initialUseImperial,
    required this.initialShowGrid,
    required this.onUseImperialChanged,
    required this.onShowGridChanged,
    this.initialQuoteRates = const QuoteRates(),
    this.onQuoteRatesChanged,
  });

  @override
  State<ProjectSettingsSheet> createState() => _ProjectSettingsSheetState();
}

class _ProjectSettingsSheetState extends State<ProjectSettingsSheet> {
  late double _wallWidthMm;
  double? _doorThicknessMm;
  late bool _useImperial;
  late bool _showGrid;

  late final TextEditingController _underlayController;
  late final TextEditingController _gripperController;
  late final TextEditingController _doorBarController;
  late final TextEditingController _labourController;
  late final TextEditingController _stairLabourController;
  late final TextEditingController _gstController;
  late bool _includeGst;

  static String _rateText(double? v) => v == null
      ? ''
      : (v == v.roundToDouble() ? v.round().toString() : v.toString());

  @override
  void initState() {
    super.initState();
    _wallWidthMm = widget.initialWallWidthMm.clamp(10.0, 500.0);
    _doorThicknessMm = widget.initialDoorThicknessMm?.clamp(10.0, 500.0);
    _useImperial = widget.initialUseImperial;
    _showGrid = widget.initialShowGrid;
    final rates = widget.initialQuoteRates;
    _underlayController =
        TextEditingController(text: _rateText(rates.underlayCostPerSqm));
    _gripperController =
        TextEditingController(text: _rateText(rates.gripperCostPerM));
    _doorBarController =
        TextEditingController(text: _rateText(rates.doorBarCostEach));
    _labourController =
        TextEditingController(text: _rateText(rates.labourCostPerSqm));
    _stairLabourController =
        TextEditingController(text: _rateText(rates.stairLabourPerStep));
    _gstController = TextEditingController(text: _rateText(rates.gstPercent));
    _includeGst = rates.includeGst;
  }

  @override
  void dispose() {
    _underlayController.dispose();
    _gripperController.dispose();
    _doorBarController.dispose();
    _labourController.dispose();
    _stairLabourController.dispose();
    _gstController.dispose();
    super.dispose();
  }

  /// Rates from the current field values. Empty field = rate not set.
  QuoteRates _collectQuoteRates() {
    double? parse(TextEditingController c) {
      final v = double.tryParse(c.text.trim());
      return v != null && v >= 0 ? v : null;
    }

    return QuoteRates(
      underlayCostPerSqm: parse(_underlayController),
      gripperCostPerM: parse(_gripperController),
      doorBarCostEach: parse(_doorBarController),
      labourCostPerSqm: parse(_labourController),
      stairLabourPerStep: parse(_stairLabourController),
      gstPercent:
          parse(_gstController) ?? widget.initialQuoteRates.gstPercent,
      includeGst: _includeGst,
    );
  }

  Widget _rateField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        hintText: 'empty = not priced',
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: SingleChildScrollView(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Project settings',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Walls',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Controls how thick completed room walls are drawn on the canvas (in mm).',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Slider(
                  min: 10,
                  max: 300,
                  divisions: 58,
                  value: _wallWidthMm.clamp(10.0, 300.0),
                  label: '${_wallWidthMm.round()} mm',
                  onChanged: (v) {
                    setState(() {
                      _wallWidthMm = v;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 72,
                child: Text(
                  '${_wallWidthMm.round()} mm',
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Doors (optional)',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Override door thickness independently of wall thickness. Leave empty to match wall thickness.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Slider(
                  min: 10,
                  max: 300,
                  divisions: 58,
                  value: (_doorThicknessMm ?? _wallWidthMm).clamp(10.0, 300.0),
                  label: '${(_doorThicknessMm ?? _wallWidthMm).round()} mm',
                  onChanged: (v) {
                    setState(() {
                      _doorThicknessMm = v;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 72,
                child: Text(
                  '${(_doorThicknessMm ?? _wallWidthMm).round()} mm',
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Display',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Use imperial units'),
            subtitle: const Text('Switch between metric (mm/cm/m) and imperial (ft/in).'),
            value: _useImperial,
            onChanged: (v) {
              setState(() {
                _useImperial = v;
              });
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Show grid'),
            subtitle: const Text('Toggle the drawing grid on the canvas.'),
            value: _showGrid,
            onChanged: (v) {
              setState(() {
                _showGrid = v;
              });
            },
          ),
          if (widget.onQuoteRatesChanged != null) ...[
            const SizedBox(height: 16),
            Text(
              'Quote rates',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Prices for the job quote on the PDF export. Leave a field empty to show the quantity unpriced.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            _rateField(_underlayController, 'Underlay (\$/m²)'),
            const SizedBox(height: 12),
            _rateField(_gripperController, 'Gripper (\$/m)'),
            const SizedBox(height: 12),
            _rateField(_doorBarController, 'Door bar (\$ each)'),
            const SizedBox(height: 12),
            _rateField(_labourController, 'Installation labour (\$/m²)'),
            const SizedBox(height: 12),
            _rateField(_stairLabourController, 'Stair labour (\$/step)'),
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(width: 120, child: _rateField(_gstController, 'GST (%)')),
                const SizedBox(width: 8),
                Expanded(
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Add GST'),
                    value: _includeGst,
                    onChanged: (v) {
                      setState(() {
                        _includeGst = v;
                      });
                    },
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: () {
                widget.onWallWidthChanged(_wallWidthMm);
                if (widget.onDoorThicknessChanged != null) {
                  widget.onDoorThicknessChanged!(_doorThicknessMm);
                }
                widget.onUseImperialChanged(_useImperial);
                widget.onShowGridChanged(_showGrid);
                widget.onQuoteRatesChanged?.call(_collectQuoteRates());
                Navigator.of(context).pop();
              },
              child: const Text('Apply'),
            ),
          ),
        ],
        ),
      ),
    );
  }
}

