import 'dart:ui';
import '../../core/geometry/room.dart';

/// Snapshot of plan state for undo/redo (completed rooms + optional draft vertices).
typedef PlanHistorySnapshot = ({List<Room> rooms, List<Offset>? draftVertices});

/// Manages undo/redo history for the plan canvas.
/// State is saved *before* each action so one undo restores the previous state.
class PlanHistoryManager {
  final List<PlanHistorySnapshot> _history = [];
  int _index = -1;

  static const int maxHistorySize = 50;

  bool get canUndo => _index >= 0;
  bool get canRedo => _index < _history.length - 1;

  void save(List<Room> rooms, List<Offset>? draftVertices) {
    if (_index < _history.length - 1) {
      _history.removeRange(_index + 1, _history.length);
    }
    final roomsCopy = rooms.map((r) => Room(
      vertices: List<Offset>.from(r.vertices),
      name: r.name,
    )).toList();
    final draftCopy = draftVertices != null ? List<Offset>.from(draftVertices) : null;
    _history.add((rooms: roomsCopy, draftVertices: draftCopy));
    _index = _history.length - 1;
    if (_history.length > maxHistorySize) {
      _history.removeAt(0);
      _index--;
    }
  }

  PlanHistorySnapshot? undo() {
    if (_index < 0) return null;
    final state = _history[_index];
    _index--;
    return state;
  }

  PlanHistorySnapshot? redo() {
    if (_index >= _history.length - 1) return null;
    _index++;
    return _history[_index];
  }
}
