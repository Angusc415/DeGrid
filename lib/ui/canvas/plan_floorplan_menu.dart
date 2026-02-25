import 'package:flutter/material.dart';

class PlanFloorplanContextMenu extends StatelessWidget {
  final bool locked;
  final double opacity;
  final bool isMoveMode;
  final VoidCallback onToggleLock;
  final VoidCallback onFit;
  final VoidCallback onReset;
  final VoidCallback onToggleMoveMode;
  final VoidCallback onDelete;
  final ValueChanged<double> onOpacityChanged;

  const PlanFloorplanContextMenu({
    super.key,
    required this.locked,
    required this.opacity,
    required this.isMoveMode,
    required this.onToggleLock,
    required this.onFit,
    required this.onReset,
    required this.onToggleMoveMode,
    required this.onDelete,
    required this.onOpacityChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.zero,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Floorplan',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: Icon(locked ? Icons.lock : Icons.lock_open),
                tooltip: locked ? 'Unlock' : 'Lock',
                color: locked ? Colors.orange : null,
                onPressed: onToggleLock,
              ),
              IconButton(
                icon: const Icon(Icons.fit_screen),
                tooltip: 'Fit to view',
                onPressed: onFit,
              ),
              IconButton(
                icon: const Icon(Icons.restart_alt),
                tooltip: 'Reset size',
                onPressed: onReset,
              ),
              IconButton(
                icon: Icon(
                  Icons.pan_tool,
                  color: isMoveMode ? Theme.of(context).colorScheme.primary : null,
                ),
                tooltip: 'Move floorplan',
                onPressed: locked ? null : onToggleMoveMode,
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                tooltip: 'Remove floorplan image',
                onPressed: onDelete,
              ),
              const SizedBox(width: 12),
              Text('Opacity', style: Theme.of(context).textTheme.bodySmall),
              SizedBox(
                width: 120,
                child: Slider(
                  value: opacity.clamp(0.0, 1.0),
                  onChanged: onOpacityChanged,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
