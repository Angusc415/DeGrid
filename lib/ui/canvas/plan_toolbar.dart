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
          
          // Zoom controls (custom dropdown that stays open)
          _ZoomMenuButton(
            onZoomIn: onZoomIn,
            onZoomOut: onZoomOut,
            onFitToScreen: onFitToScreen,
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

/// Custom zoom menu button that stays open until clicking outside.
class _ZoomMenuButton extends StatefulWidget {
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onFitToScreen;

  const _ZoomMenuButton({
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onFitToScreen,
  });

  @override
  State<_ZoomMenuButton> createState() => _ZoomMenuButtonState();
}

class _ZoomMenuButtonState extends State<_ZoomMenuButton> {
  OverlayEntry? _overlayEntry;
  bool _isMenuOpen = false;

  void _showMenu() {
    if (_isMenuOpen) return;

    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Invisible backdrop to catch taps outside menu
          Positioned.fill(
            child: GestureDetector(
              onTap: () => _hideMenu(), // Close when tapping outside
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.transparent),
            ),
          ),
          // Menu positioned below toolbar
          Positioned(
            left: offset.dx,
            top: offset.dy + size.height + 4, // Position below toolbar with small gap
            child: GestureDetector(
              onTap: () {}, // Prevent taps on menu from closing it
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  width: 180,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildMenuItem(
                        icon: Icons.zoom_in,
                        label: 'Zoom In',
                        onTap: () {
                          widget.onZoomIn();
                          // Don't close menu - keep it open
                        },
                      ),
                      const Divider(height: 1),
                      _buildMenuItem(
                        icon: Icons.zoom_out,
                        label: 'Zoom Out',
                        onTap: () {
                          widget.onZoomOut();
                          // Don't close menu - keep it open
                        },
                      ),
                      const Divider(height: 1),
                      _buildMenuItem(
                        icon: Icons.fit_screen,
                        label: 'Fit to Screen',
                        onTap: () {
                          widget.onFitToScreen();
                          // Don't close menu - keep it open
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    setState(() {
      _isMenuOpen = true;
    });
  }

  void _hideMenu() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    setState(() {
      _isMenuOpen = false;
    });
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 12),
            Text(label),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _hideMenu();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Zoom Options',
      child: IconButton(
        icon: Icon(
          Icons.zoom_in,
          color: _isMenuOpen ? Colors.blue : null,
        ),
        tooltip: 'Zoom Options',
        onPressed: _isMenuOpen ? _hideMenu : _showMenu,
      ),
    );
  }
}
