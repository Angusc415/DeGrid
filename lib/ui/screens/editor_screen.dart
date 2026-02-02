import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../canvas/plan_canvas.dart';
import '../../core/geometry/room.dart';
import 'room_area_summary_panel.dart';

class EditorScreen extends StatefulWidget {
  final int? projectId;
  final String? projectName;

  const EditorScreen({
    super.key,
    this.projectId,
    this.projectName,
  });

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final GlobalKey<PlanCanvasState> _planCanvasKey = GlobalKey<PlanCanvasState>();
  List<Room> _rooms = [];
  bool _useImperial = false;
  int? _selectedRoomIndex;
  bool _isPanelOpen = false;

  void _onRoomsChanged(List<Room> rooms, bool useImperial, int? selectedIndex) {
    setState(() {
      _rooms = rooms;
      _useImperial = useImperial;
      _selectedRoomIndex = selectedIndex;
    });
  }

  void _onRoomSelected(int roomIndex) {
    // Access the state through the GlobalKey
    _planCanvasKey.currentState?.selectRoom(roomIndex);
    setState(() {
      _selectedRoomIndex = roomIndex;
    });
    // Close drawer on mobile after selection
    if (!kIsWeb && _isPanelOpen) {
      Navigator.of(context).pop();
      _isPanelOpen = false;
    }
  }

  void _onRoomDeleted(int roomIndex) {
    // Access the state through the GlobalKey to delete room
    _planCanvasKey.currentState?.deleteRoom(roomIndex);
  }

  void _togglePanel(BuildContext scaffoldContext) {
    if (kIsWeb) {
      // On web, toggle panel visibility
      setState(() {
        _isPanelOpen = !_isPanelOpen;
      });
    } else {
      // On mobile, use drawer
      Scaffold.of(scaffoldContext).openEndDrawer();
      setState(() {
        _isPanelOpen = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.projectName ?? 'New Project'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.view_list),
              tooltip: 'Room Summary',
              onPressed: () => _togglePanel(context),
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          // Main canvas area
          Expanded(
            child: SafeArea(
              child: PlanCanvas(
                key: _planCanvasKey,
                projectId: widget.projectId,
                initialProjectName: widget.projectName,
                onRoomsChanged: _onRoomsChanged,
              ),
            ),
          ),
          // Side panel (web/desktop only, when open)
          if (kIsWeb && _isPanelOpen)
            RoomAreaSummaryPanel(
              rooms: _rooms,
              useImperial: _useImperial,
              selectedRoomIndex: _selectedRoomIndex,
              onRoomSelected: _onRoomSelected,
              onRoomDeleted: _onRoomDeleted,
            ),
        ],
      ),
      // Drawer for mobile
      endDrawer: kIsWeb
          ? null
          : Drawer(
              width: 320,
              child: RoomAreaSummaryPanel(
                rooms: _rooms,
                useImperial: _useImperial,
                selectedRoomIndex: _selectedRoomIndex,
                onRoomSelected: _onRoomSelected,
                onRoomDeleted: _onRoomDeleted,
              ),
            ),
    );
  }
}
