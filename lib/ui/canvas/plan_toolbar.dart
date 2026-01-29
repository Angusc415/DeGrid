import 'package:flutter/material.dart';

/// Toolbar widget for the plan canvas with unit toggle, grid toggle, and undo/redo.
class PlanToolbar extends StatelessWidget {
  final bool useImperial;
  final bool showGrid;
  final bool canUndo;
  final bool canRedo;
  final VoidCallback onToggleUnit;
  final VoidCallback onToggleGrid;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final bool hasSelectedRoom;
  final VoidCallback? onDeleteRoom;

  const PlanToolbar({
    super.key,
    required this.useImperial,
    required this.showGrid,
    required this.canUndo,
    required this.canRedo,
    this.hasSelectedRoom = false,
    this.onDeleteRoom,
    required this.onToggleUnit,
    required this.onToggleGrid,
    required this.onUndo,
    required this.onRedo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Unit toggle button
          Tooltip(
            message: useImperial ? 'Switch to Metric (mm/cm)' : 'Switch to Imperial (ft/in)',
            child: IconButton(
              icon: Icon(useImperial ? Icons.straighten : Icons.square_foot),
              tooltip: useImperial ? 'Metric' : 'Imperial',
              onPressed: onToggleUnit,
            ),
          ),
          
          const VerticalDivider(width: 8),
          
          // Grid visibility toggle
          Tooltip(
            message: showGrid ? 'Hide Grid' : 'Show Grid',
            child: IconButton(
              icon: Icon(showGrid ? Icons.grid_on : Icons.grid_off),
              tooltip: showGrid ? 'Hide Grid' : 'Show Grid',
              onPressed: onToggleGrid,
            ),
          ),
          
          const VerticalDivider(width: 8),
          
          // Undo button
          Tooltip(
            message: 'Undo (Ctrl+Z)',
            child: IconButton(
              icon: const Icon(Icons.undo),
              tooltip: 'Undo',
              onPressed: canUndo ? onUndo : null,
            ),
          ),
          
          // Redo button
          Tooltip(
            message: 'Redo (Ctrl+Shift+Z)',
            child: IconButton(
              icon: const Icon(Icons.redo),
              tooltip: 'Redo',
              onPressed: canRedo ? onRedo : null,
            ),
          ),
          
          if (hasSelectedRoom && onDeleteRoom != null) ...[
            const VerticalDivider(width: 8),
            
            // Delete room button
            Tooltip(
              message: 'Delete Selected Room (Delete/Backspace)',
              child: IconButton(
                icon: const Icon(Icons.delete),
                tooltip: 'Delete Room',
                color: Colors.red,
                onPressed: onDeleteRoom,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
