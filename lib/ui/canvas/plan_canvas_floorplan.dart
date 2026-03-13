part of 'plan_canvas.dart';

void _showMoveRoomPromptImpl(PlanCanvasState state) {
  if (!state.mounted) return;
  final overlay = Overlay.of(state.context);
  final theme = Theme.of(state.context);
  final entry = OverlayEntry(
    builder: (context) => Positioned(
      top: 72,
      left: 24,
      right: 24,
      child: Center(
        child: Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(8),
          color: theme.colorScheme.inverseSurface,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Text(
              'Move room — drag to reposition',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onInverseSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  Future.delayed(const Duration(milliseconds: 1800), () {
    entry.remove();
  });
}

Offset? _screenToBackgroundImagePixelImpl(
  PlanCanvasState state,
  Offset screenPx,
) {
  if (state._backgroundImageState == null) return null;
  final world = state._vp.screenToWorld(screenPx);
  final scale = state._backgroundImageState!.effectiveScaleMmPerPixel;
  final ox = state._backgroundImageState!.offsetX;
  final oy = state._backgroundImageState!.offsetY;
  return Offset((world.dx - ox) / scale, (world.dy - oy) / scale);
}

bool _isPointOnBackgroundImageImpl(PlanCanvasState state, Offset screenPx) {
  if (state._backgroundImage == null || state._backgroundImageState == null) {
    return false;
  }
  final px = _screenToBackgroundImagePixelImpl(state, screenPx);
  if (px == null) return false;
  final width = state._backgroundImage!.width.toDouble();
  final height = state._backgroundImage!.height.toDouble();
  const tolerance = 1.0;
  return px.dx >= -tolerance &&
      px.dx <= width + tolerance &&
      px.dy >= -tolerance &&
      px.dy <= height + tolerance;
}

Rect? _backgroundImageScreenRectImpl(PlanCanvasState state) {
  if (state._backgroundImage == null || state._backgroundImageState == null) {
    return null;
  }
  final scale = state._backgroundImageState!.effectiveScaleMmPerPixel;
  final ox = state._backgroundImageState!.offsetX;
  final oy = state._backgroundImageState!.offsetY;
  final widthMm = state._backgroundImage!.width * scale;
  final heightMm = state._backgroundImage!.height * scale;
  final tl = state._vp.worldToScreen(Offset(ox, oy));
  final tr = state._vp.worldToScreen(Offset(ox + widthMm, oy));
  final br = state._vp.worldToScreen(Offset(ox + widthMm, oy + heightMm));
  final bl = state._vp.worldToScreen(Offset(ox, oy + heightMm));
  final minX = math.min(math.min(tl.dx, tr.dx), math.min(bl.dx, br.dx));
  final minY = math.min(math.min(tl.dy, tr.dy), math.min(bl.dy, br.dy));
  final maxX = math.max(math.max(tl.dx, tr.dx), math.max(bl.dx, br.dx));
  final maxY = math.max(math.max(tl.dy, tr.dy), math.max(bl.dy, br.dy));
  return Rect.fromLTRB(minX, minY, maxX, maxY);
}

void _startFloorplanResizeImpl(
  PlanCanvasState state,
  int cornerIndex,
  Offset cornerScreen,
  Offset globalPosition,
) {
  if (state._backgroundImageState == null || state._backgroundImage == null) {
    return;
  }
  final scale = state._backgroundImageState!.effectiveScaleMmPerPixel;
  final ox = state._backgroundImageState!.offsetX;
  final oy = state._backgroundImageState!.offsetY;
  final width = state._backgroundImage!.width.toDouble();
  final height = state._backgroundImage!.height.toDouble();
  final widthMm = width * scale;
  final heightMm = height * scale;
  final anchorWorld = switch (cornerIndex) {
    0 => Offset(ox + widthMm, oy + heightMm),
    1 => Offset(ox, oy + heightMm),
    2 => Offset(ox, oy),
    3 => Offset(ox + widthMm, oy),
    _ => Offset(ox, oy),
  };
  state._floorplanResizeStartGlobal = globalPosition;
  state._floorplanResizeStartCornerScreen = cornerScreen;
  state._floorplanResizeCornerIndex = cornerIndex;
  state._floorplanResizeAnchorWorld = anchorWorld;
}

void _updateFloorplanResizeImpl(PlanCanvasState state, Offset globalPosition) {
  if (state._backgroundImageState == null ||
      state._backgroundImage == null ||
      state._floorplanResizeStartGlobal == null ||
      state._floorplanResizeCornerIndex == null ||
      state._floorplanResizeAnchorWorld == null) {
    return;
  }
  final cornerIndex = state._floorplanResizeCornerIndex!;
  final anchorWorld = state._floorplanResizeAnchorWorld!;
  final dragVector = globalPosition - state._floorplanResizeStartGlobal!;
  final newCornerScreen = state._floorplanResizeStartCornerScreen! + dragVector;
  final newCornerWorld = state._vp.screenToWorld(newCornerScreen);

  final width = state._backgroundImage!.width.toDouble();
  final height = state._backgroundImage!.height.toDouble();
  final diagonal = math.sqrt(width * width + height * height);
  if (diagonal <= 0) return;
  final scaleMmPerPixel = state._backgroundImageState!.scaleMmPerPixel;
  final distanceMm = (newCornerWorld - anchorWorld).distance;
  var newScale = distanceMm / diagonal;
  if (newScale <= 0) return;
  var newScaleFactor = scaleMmPerPixel / newScale;
  newScaleFactor = newScaleFactor.clamp(0.25, 2.0);
  newScale = scaleMmPerPixel / newScaleFactor;

  double newOx;
  double newOy;
  switch (cornerIndex) {
    case 0:
      newOx = anchorWorld.dx - width * newScale;
      newOy = anchorWorld.dy - height * newScale;
      break;
    case 1:
      newOx = anchorWorld.dx;
      newOy = anchorWorld.dy - height * newScale;
      break;
    case 2:
      newOx = anchorWorld.dx;
      newOy = anchorWorld.dy;
      break;
    case 3:
      newOx = anchorWorld.dx - width * newScale;
      newOy = anchorWorld.dy;
      break;
    default:
      return;
  }

  state.setState(() {
    state._backgroundImageState = state._backgroundImageState!.copyWith(
      scaleFactor: newScaleFactor,
      offsetX: newOx,
      offsetY: newOy,
    );
    state._hasUnsavedChanges = true;
  });
}

void _endFloorplanResizeImpl(PlanCanvasState state) {
  state._floorplanResizeStartGlobal = null;
  state._floorplanResizeStartCornerScreen = null;
  state._floorplanResizeCornerIndex = null;
  state._floorplanResizeAnchorWorld = null;
}
