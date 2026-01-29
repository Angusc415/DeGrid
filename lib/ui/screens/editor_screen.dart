import 'package:flutter/material.dart';
import '../canvas/plan_canvas.dart';

class EditorScreen extends StatelessWidget {
  const EditorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: PlanCanvas(),
      ),
    );
  }
}
