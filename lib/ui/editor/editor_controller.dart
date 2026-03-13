import 'package:flutter/foundation.dart';

import '../../core/geometry/carpet_product.dart';
import '../../core/geometry/opening.dart';
import '../../core/geometry/room.dart';

@immutable
class EditorViewState {
  final List<Room> rooms;
  final bool useImperial;
  final bool showGrid;
  final int? selectedRoomIndex;
  final double wallWidthMm;
  final double? doorThicknessMm;
  final List<CarpetProduct> carpetProducts;
  final Map<int, int> roomCarpetAssignments;
  final List<Opening> openings;
  final Map<int, List<double>> roomCarpetSeamOverrides;
  final Map<int, double> roomCarpetSeamLayDirectionDeg;
  final Map<int, int> roomCarpetLayoutVariantIndex;

  const EditorViewState({
    this.rooms = const [],
    this.useImperial = false,
    this.showGrid = true,
    this.selectedRoomIndex,
    this.wallWidthMm = 70.0,
    this.doorThicknessMm,
    this.carpetProducts = const [],
    this.roomCarpetAssignments = const {},
    this.openings = const [],
    this.roomCarpetSeamOverrides = const {},
    this.roomCarpetSeamLayDirectionDeg = const {},
    this.roomCarpetLayoutVariantIndex = const {},
  });
}

/// Thin seam between the editor shell and the canvas implementation.
class EditorController extends ChangeNotifier {
  EditorViewState _state = const EditorViewState();

  void Function(int roomIndex)? _selectRoom;
  void Function(int roomIndex)? _deleteRoom;
  void Function(List<CarpetProduct> products)? _setCarpetProducts;
  void Function(int roomIndex, int? productIndex)? _setRoomCarpet;
  void Function(int roomIndex, int variantIndex)? _setRoomLayoutVariant;
  void Function(int roomIndex)? _clearSeamOverridesForRoom;
  void Function(double value)? _setWallWidthMm;
  void Function(double? value)? _setDoorThicknessMm;
  void Function(bool value)? _setUseImperial;
  void Function(bool value)? _setShowGrid;

  EditorViewState get state => _state;

  void bind({
    required void Function(int roomIndex) selectRoom,
    required void Function(int roomIndex) deleteRoom,
    required void Function(List<CarpetProduct> products) setCarpetProducts,
    required void Function(int roomIndex, int? productIndex) setRoomCarpet,
    required void Function(int roomIndex, int variantIndex)
    setRoomLayoutVariant,
    required void Function(int roomIndex) clearSeamOverridesForRoom,
    required void Function(double value) setWallWidthMm,
    required void Function(double? value) setDoorThicknessMm,
    required void Function(bool value) setUseImperial,
    required void Function(bool value) setShowGrid,
  }) {
    _selectRoom = selectRoom;
    _deleteRoom = deleteRoom;
    _setCarpetProducts = setCarpetProducts;
    _setRoomCarpet = setRoomCarpet;
    _setRoomLayoutVariant = setRoomLayoutVariant;
    _clearSeamOverridesForRoom = clearSeamOverridesForRoom;
    _setWallWidthMm = setWallWidthMm;
    _setDoorThicknessMm = setDoorThicknessMm;
    _setUseImperial = setUseImperial;
    _setShowGrid = setShowGrid;
  }

  void unbind() {
    _selectRoom = null;
    _deleteRoom = null;
    _setCarpetProducts = null;
    _setRoomCarpet = null;
    _setRoomLayoutVariant = null;
    _clearSeamOverridesForRoom = null;
    _setWallWidthMm = null;
    _setDoorThicknessMm = null;
    _setUseImperial = null;
    _setShowGrid = null;
  }

  void updateState(EditorViewState state) {
    _state = state;
    notifyListeners();
  }

  void selectRoom(int roomIndex) => _selectRoom?.call(roomIndex);

  void deleteRoom(int roomIndex) => _deleteRoom?.call(roomIndex);

  void setCarpetProducts(List<CarpetProduct> products) =>
      _setCarpetProducts?.call(products);

  void setRoomCarpet(int roomIndex, int? productIndex) =>
      _setRoomCarpet?.call(roomIndex, productIndex);

  void setRoomLayoutVariant(int roomIndex, int variantIndex) =>
      _setRoomLayoutVariant?.call(roomIndex, variantIndex);

  void clearSeamOverridesForRoom(int roomIndex) =>
      _clearSeamOverridesForRoom?.call(roomIndex);

  void setWallWidthMm(double value) => _setWallWidthMm?.call(value);

  void setDoorThicknessMm(double? value) => _setDoorThicknessMm?.call(value);

  void setUseImperial(bool value) => _setUseImperial?.call(value);

  void setShowGrid(bool value) => _setShowGrid?.call(value);
}
