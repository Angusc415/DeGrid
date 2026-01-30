import 'package:flutter/material.dart';

/// Toolbar widget for the plan canvas with unit toggle, grid toggle, and undo/redo.
class PlanToolbar extends StatelessWidget {
  final bool useImperial;
  final bool showGrid;
  final bool isPanMode;
  final bool canUndo;
  final bool canRedo;
  final VoidCallback onToggleUnit;
  final VoidCallback onToggleGrid;
  final VoidCallback onTogglePanMode;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onFitToScreen;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final bool hasSelectedRoom;
  final VoidCallback? onDeleteRoom;
  final bool hasProject;
  final bool hasUnsavedChanges;
  final VoidCallback? onSave;

  const PlanToolbar({
    super.key,
    required this.useImperial,
    required this.showGrid,
    required this.isPanMode,
    required this.canUndo,
    required this.canRedo,
    this.hasSelectedRoom = false,
    this.onDeleteRoom,
    this.hasProject = false,
    this.hasUnsavedChanges = false,
    this.onSave,
    required this.onToggleUnit,
    required this.onToggleGrid,
    required this.onTogglePanMode,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onFitToScreen,
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
          
          // Pan mode toggle (mobile: single-finger drag pans when enabled)
          Tooltip(
            message: isPanMode ? 'Pan Mode: Drag to pan (tap to exit)' : 'Draw Mode: Drag to draw (tap to enter pan mode)',
            child: IconButton(
              icon: Icon(isPanMode ? Icons.pan_tool : Icons.edit),
              tooltip: isPanMode ? 'Pan Mode' : 'Draw Mode',
              color: isPanMode ? Colors.blue : null,
              onPressed: onTogglePanMode,
            ),
          ),
          
          const VerticalDivider(width: 8),
          
          // Zoom controls (popup menu)
          PopupMenuButton<String>(
            tooltip: 'Zoom Options',
            icon: const Icon(Icons.zoom_in),
            onSelected: (value) {
              switch (value) {
                case 'zoom_in':
                  onZoomIn();
                  break;
                case 'zoom_out':
                  onZoomOut();
                  break;
                case 'fit_screen':
                  onFitToScreen();
                  break;
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'zoom_in',
                child: Row(
                  children: [
                    Icon(Icons.zoom_in, size: 20),
                    SizedBox(width: 8),
                    Text('Zoom In'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'zoom_out',
                child: Row(
                  children: [
                    Icon(Icons.zoom_out, size: 20),
                    SizedBox(width: 8),
                    Text('Zoom Out'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'fit_screen',
                child: Row(
                  children: [
                    Icon(Icons.fit_screen, size: 20),
                    SizedBox(width: 8),
                    Text('Fit to Screen'),
                  ],
                ),
              ),
            ],
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
          
          if (onSave != null) ...[
            const VerticalDivider(width: 8),
            
            // Save button
            Tooltip(
              message: hasProject
                  ? (hasUnsavedChanges ? 'Save Project (Ctrl+S)' : 'No unsaved changes')
                  : (hasUnsavedChanges ? 'Save as New Project (Ctrl+S)' : 'Save Project'),
              child: IconButton(
                icon: Icon(
                  Icons.save,
                  color: hasUnsavedChanges ? Colors.orange : null,
                ),
                tooltip: 'Save',
                // Enable save if there are unsaved changes (even for new projects)
                // or if there's a project (to allow saving even when no changes, in case user wants to)
                onPressed: hasUnsavedChanges || hasProject ? onSave : null,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
