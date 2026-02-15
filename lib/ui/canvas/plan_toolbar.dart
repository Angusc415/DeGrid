import 'package:flutter/material.dart';

/// Which section of the toolbar to show (for collapsible corner menus).
enum ToolbarSection { main, dimensions }

/// Wraps toolbar content in a collapsible menu.
/// Collapsed: single icon. Expanded: full [child] with a close button to collapse.
class CollapsibleToolbar extends StatefulWidget {
  final Widget child;
  final String tooltip;
  final IconData icon;
  final bool initialExpanded;

  const CollapsibleToolbar({
    super.key,
    required this.child,
    this.tooltip = 'Menu',
    this.icon = Icons.menu,
    this.initialExpanded = false,
  });

  @override
  State<CollapsibleToolbar> createState() => _CollapsibleToolbarState();
}

class _CollapsibleToolbarState extends State<CollapsibleToolbar> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initialExpanded;
  }

  static final _toolbarDecoration = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(8),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.1),
        blurRadius: 4,
        offset: const Offset(0, 2),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    if (!_expanded) {
      return Material(
        elevation: 2,
        borderRadius: BorderRadius.circular(8),
        child: Tooltip(
          message: widget.tooltip,
          child: InkWell(
            onTap: () => setState(() => _expanded = true),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(widget.icon),
            ),
          ),
        ),
      );
    }
    return Container(
      decoration: _toolbarDecoration,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Tooltip(
            message: 'Close menu',
            child: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() => _expanded = false),
            ),
          ),
          const VerticalDivider(width: 1, thickness: 1),
          widget.child,
        ],
      ),
    );
  }
}

/// Toolbar widget for the plan canvas with unit toggle, grid toggle, and undo/redo.
/// When [section] is set, builds only that section (for use in collapsible corner menus).
class PlanToolbar extends StatelessWidget {
  final ToolbarSection? section;
  final bool useImperial;
  final bool showGrid;
  final bool isPanMode;
  final bool canUndo;
  final bool canRedo;
  final VoidCallback onToggleUnit;
  final VoidCallback onToggleGrid;
  final VoidCallback onTogglePanMode;
  final VoidCallback onCalibrate;
  final bool isCalibrating;
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
  final bool isMeasureMode;
  final VoidCallback? onToggleMeasureMode;
  final bool isAddDimensionMode;
  final VoidCallback? onToggleAddDimensionMode;
  final bool isAddDoorMode;
  final VoidCallback? onToggleAddDoorMode;
  final bool hasPlacedDimensions;
  final VoidCallback? onRemoveLastDimension;
  final bool isAngleLocked;
  final VoidCallback? onToggleAngleLock;
  final bool isDrawing;
  final bool showNumberPad;
  final VoidCallback? onToggleNumberPad;
  final bool drawFromStart;
  final VoidCallback? onToggleDrawFromStart;
  final VoidCallback? onImportFloorplan;
  final double? backgroundImageOpacity;
  final ValueChanged<double>? onBackgroundOpacityChanged;
  final double? backgroundImageScaleFactor;
  final ValueChanged<double>? onBackgroundScaleFactorChanged;
  final bool hasBackgroundImage;
  final bool isFloorplanLocked;
  final VoidCallback? onToggleFloorplanLock;
  final VoidCallback? onFitFloorplan;
  final VoidCallback? onResetFloorplan;
  final bool isMoveFloorplanMode;
  final VoidCallback? onToggleMoveFloorplanMode;

  const PlanToolbar({
    super.key,
    this.section,
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
    this.isMeasureMode = false,
    this.onToggleMeasureMode,
    this.isAddDimensionMode = false,
    this.onToggleAddDimensionMode,
    this.isAddDoorMode = false,
    this.onToggleAddDoorMode,
    this.hasPlacedDimensions = false,
    this.onRemoveLastDimension,
    this.isAngleLocked = false,
    this.onToggleAngleLock,
    this.isDrawing = false,
    this.showNumberPad = true,
    this.onToggleNumberPad,
    this.drawFromStart = false,
    this.onToggleDrawFromStart,
    this.onImportFloorplan,
    this.backgroundImageOpacity,
    this.onBackgroundOpacityChanged,
    this.backgroundImageScaleFactor,
    this.onBackgroundScaleFactorChanged,
    this.hasBackgroundImage = false,
    this.isFloorplanLocked = false,
    this.onToggleFloorplanLock,
    this.onFitFloorplan,
    this.onResetFloorplan,
    this.isMoveFloorplanMode = false,
    this.onToggleMoveFloorplanMode,
    required this.onToggleUnit,
    required this.onToggleGrid,
    required this.onTogglePanMode,
    required this.onCalibrate,
    this.isCalibrating = false,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onFitToScreen,
    required this.onUndo,
    required this.onRedo,
  });

  static final _toolbarDecoration = BoxDecoration(
    color: Colors.white,
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.1),
        blurRadius: 4,
        offset: const Offset(0, 2),
      ),
    ],
  );

  static const _toolbarPadding = EdgeInsets.symmetric(horizontal: 12, vertical: 8);

  Widget _buildMainRow(BuildContext context) {
    return Padding(
      padding: _toolbarPadding,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Tooltip(
            message: useImperial ? 'Switch to Metric (mm/cm)' : 'Switch to Imperial (ft/in)',
            child: IconButton(
              icon: Icon(useImperial ? Icons.straighten : Icons.square_foot),
              tooltip: useImperial ? 'Metric' : 'Imperial',
              onPressed: onToggleUnit,
            ),
          ),
          const VerticalDivider(width: 8),
          Tooltip(
            message: showGrid ? 'Hide Grid' : 'Show Grid',
            child: IconButton(
              icon: Icon(showGrid ? Icons.grid_on : Icons.grid_off),
              tooltip: showGrid ? 'Hide Grid' : 'Show Grid',
              onPressed: onToggleGrid,
            ),
          ),
          const VerticalDivider(width: 8),
          Tooltip(
            message: isPanMode ? 'Pan Mode: Drag to pan (tap to exit)' : 'Draw Mode: Drag to draw (tap to enter pan mode)',
            child: IconButton(
              icon: Icon(isPanMode ? Icons.pan_tool : Icons.edit),
              tooltip: isPanMode ? 'Pan Mode' : 'Draw Mode',
              color: isPanMode ? Colors.blue : null,
              onPressed: onTogglePanMode,
            ),
          ),
          if (onToggleAngleLock != null) ...[
            const VerticalDivider(width: 8),
            Tooltip(
              message: isAngleLocked ? 'Lock angle (snap to 45°/90°)' : 'Unlock angle (free draw)',
              child: IconButton(
                icon: Icon(isAngleLocked ? Icons.lock : Icons.lock_open),
                tooltip: isAngleLocked ? 'Lock' : 'Unlock',
                onPressed: onToggleAngleLock,
              ),
            ),
          ],
          const VerticalDivider(width: 8),
          _ZoomMenuButton(
            onZoomIn: onZoomIn,
            onZoomOut: onZoomOut,
            onFitToScreen: onFitToScreen,
          ),
          const VerticalDivider(width: 8),
          Tooltip(
            message: 'Undo (Ctrl+Z)',
            child: IconButton(
              icon: const Icon(Icons.undo),
              tooltip: 'Undo',
              onPressed: canUndo ? onUndo : null,
            ),
          ),
          Tooltip(
            message: 'Redo (Ctrl+Shift+Z)',
            child: IconButton(
              icon: const Icon(Icons.redo),
              tooltip: 'Redo',
              onPressed: canRedo ? onRedo : null,
            ),
          ),
          if (isDrawing && onToggleNumberPad != null) ...[
            const VerticalDivider(width: 8),
            Tooltip(
              message: showNumberPad ? 'Hide number pad' : 'Show number pad',
              child: IconButton(
                icon: Icon(showNumberPad ? Icons.dialpad : Icons.dialpad_outlined),
                tooltip: showNumberPad ? 'Hide number pad' : 'Show number pad',
                onPressed: onToggleNumberPad,
              ),
            ),
          ],
          if (isDrawing && onToggleDrawFromStart != null) ...[
            const VerticalDivider(width: 8),
            Tooltip(
              message: drawFromStart
                  ? 'Drawing from start (first point). Tap to draw from end.'
                  : 'Drawing from end (last point). Tap to draw from start.',
              child: IconButton(
                icon: const Icon(Icons.compare_arrows),
                tooltip: drawFromStart ? 'Draw from end' : 'Draw from start',
                onPressed: onToggleDrawFromStart,
              ),
            ),
          ],
          if (hasSelectedRoom && onDeleteRoom != null) ...[
            const VerticalDivider(width: 8),
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
                onPressed: hasUnsavedChanges || hasProject ? onSave : null,
              ),
            ),
          ],
          if (onImportFloorplan != null) ...[
            const VerticalDivider(width: 8),
            Tooltip(
              message: 'Import floorplan image',
              child: IconButton(
                icon: const Icon(Icons.image),
                onPressed: onImportFloorplan,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDimensionsRow(BuildContext context) {
    return Padding(
      padding: _toolbarPadding,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(
              'Dimensions',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ) ?? TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const VerticalDivider(width: 8),
          Tooltip(
            message: isCalibrating
                ? 'Calibrating: tap 2 points, enter real distance (tap to cancel)'
                : 'Calibrate scale (tap 2 points, enter real distance)',
            child: IconButton(
              icon: Icon(isCalibrating ? Icons.close : Icons.architecture),
              tooltip: isCalibrating ? 'Cancel Calibrate' : 'Calibrate',
              color: isCalibrating ? Colors.orange : null,
              onPressed: onCalibrate,
            ),
          ),
          if (onToggleMeasureMode != null)
            Tooltip(
              message: isMeasureMode
                  ? 'Measure: click and drag (release to clear)'
                  : 'Measure distance (click and drag, disappears on release)',
              child: IconButton(
                icon: const Icon(Icons.straighten),
                tooltip: isMeasureMode ? 'Exit Measure' : 'Measure',
                color: isMeasureMode ? Colors.teal : null,
                onPressed: onToggleMeasureMode,
              ),
            ),
          if (onToggleAddDimensionMode != null)
            Tooltip(
              message: isAddDimensionMode
                  ? 'Add dimension: tap 2 points to place'
                  : 'Add permanent dimension line',
              child: IconButton(
                icon: const Icon(Icons.show_chart),
                tooltip: isAddDimensionMode ? 'Exit Add Dimension' : 'Add Dimension',
                color: isAddDimensionMode ? Colors.teal : null,
                onPressed: onToggleAddDimensionMode,
              ),
            ),
          if (onToggleAddDoorMode != null)
            Tooltip(
              message: isAddDoorMode
                  ? 'Add door: tap near a wall to place'
                  : 'Add door or opening (tap near a wall)',
              child: IconButton(
                icon: const Icon(Icons.door_front_door),
                tooltip: isAddDoorMode ? 'Exit Add Door' : 'Add Door',
                color: isAddDoorMode ? Colors.brown : null,
                onPressed: onToggleAddDoorMode,
              ),
            ),
          if (hasPlacedDimensions && onRemoveLastDimension != null)
            Tooltip(
              message: 'Remove last dimension',
              child: IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                tooltip: 'Remove last dimension',
                onPressed: onRemoveLastDimension,
              ),
            ),
          if (backgroundImageOpacity != null && onBackgroundOpacityChanged != null) ...[
            const VerticalDivider(width: 8),
            Tooltip(
              message: 'Floorplan opacity',
              child: SizedBox(
                width: 72,
                child: Slider(
                  value: backgroundImageOpacity!.clamp(0.0, 1.0),
                  onChanged: onBackgroundOpacityChanged,
                ),
              ),
            ),
          ],
          if (backgroundImageScaleFactor != null && onBackgroundScaleFactorChanged != null) ...[
            const VerticalDivider(width: 8),
            Tooltip(
              message: 'Floorplan size (${(backgroundImageScaleFactor! * 100).round()}%)',
              child: SizedBox(
                width: 72,
                child: Slider(
                  value: backgroundImageScaleFactor!.clamp(0.25, 2.0),
                  min: 0.25,
                  max: 2.0,
                  onChanged: onBackgroundScaleFactorChanged,
                ),
              ),
            ),
          ],
          if (hasBackgroundImage && onToggleFloorplanLock != null) ...[
            const VerticalDivider(width: 8),
            Tooltip(
              message: isFloorplanLocked ? 'Unlock floorplan (allow move)' : 'Lock floorplan (prevent move)',
              child: IconButton(
                icon: Icon(isFloorplanLocked ? Icons.lock : Icons.lock_open),
                tooltip: isFloorplanLocked ? 'Unlock' : 'Lock',
                color: isFloorplanLocked ? Colors.orange : null,
                onPressed: onToggleFloorplanLock,
              ),
            ),
          ],
          if (hasBackgroundImage && onFitFloorplan != null) ...[
            const VerticalDivider(width: 8),
            Tooltip(
              message: 'Fit floorplan to view',
              child: IconButton(
                icon: const Icon(Icons.fit_screen),
                tooltip: 'Fit floorplan',
                onPressed: onFitFloorplan,
              ),
            ),
          ],
          if (hasBackgroundImage && onResetFloorplan != null) ...[
            const VerticalDivider(width: 8),
            Tooltip(
              message: 'Reset floorplan position and size to default',
              child: IconButton(
                icon: const Icon(Icons.restore),
                tooltip: 'Reset floorplan',
                onPressed: onResetFloorplan,
              ),
            ),
          ],
          if (hasBackgroundImage && onToggleMoveFloorplanMode != null && !isFloorplanLocked) ...[
            const VerticalDivider(width: 8),
            Tooltip(
              message: isMoveFloorplanMode
                  ? 'Move floorplan: drag to position (tap to exit)'
                  : 'Move floorplan: drag to reposition image',
              child: IconButton(
                icon: const Icon(Icons.pan_tool),
                tooltip: isMoveFloorplanMode ? 'Exit move floorplan' : 'Move floorplan',
                color: isMoveFloorplanMode ? Colors.orange : null,
                onPressed: onToggleMoveFloorplanMode,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (section == ToolbarSection.main) {
      return _buildMainRow(context);
    }
    if (section == ToolbarSection.dimensions) {
      return _buildDimensionsRow(context);
    }
    // Legacy: both rows in one column (e.g. if section is null)
    return Container(
      decoration: _toolbarDecoration,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMainRow(context),
          _buildDimensionsRow(context),
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
