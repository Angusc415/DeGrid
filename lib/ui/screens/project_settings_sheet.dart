import 'package:flutter/material.dart';

/// Simple per-project settings sheet.
class ProjectSettingsSheet extends StatefulWidget {
  final double initialWallWidthMm;
  final ValueChanged<double> onWallWidthChanged;
  final bool initialUseImperial;
  final bool initialShowGrid;
  final ValueChanged<bool> onUseImperialChanged;
  final ValueChanged<bool> onShowGridChanged;

  const ProjectSettingsSheet({
    super.key,
    required this.initialWallWidthMm,
    required this.onWallWidthChanged,
    required this.initialUseImperial,
    required this.initialShowGrid,
    required this.onUseImperialChanged,
    required this.onShowGridChanged,
  });

  @override
  State<ProjectSettingsSheet> createState() => _ProjectSettingsSheetState();
}

class _ProjectSettingsSheetState extends State<ProjectSettingsSheet> {
  late double _wallWidthMm;
  late bool _useImperial;
  late bool _showGrid;

  @override
  void initState() {
    super.initState();
    _wallWidthMm = widget.initialWallWidthMm.clamp(10.0, 500.0);
    _useImperial = widget.initialUseImperial;
    _showGrid = widget.initialShowGrid;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
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
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: () {
                widget.onWallWidthChanged(_wallWidthMm);
                widget.onUseImperialChanged(_useImperial);
                widget.onShowGridChanged(_showGrid);
                Navigator.of(context).pop();
              },
              child: const Text('Apply'),
            ),
          ),
        ],
      ),
    );
  }
}

