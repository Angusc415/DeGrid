import 'package:flutter/material.dart';
import '../canvas/plan_canvas.dart';

class EditorScreen extends StatelessWidget {
  final int? projectId;
  final String? projectName;

  const EditorScreen({
    super.key,
    this.projectId,
    this.projectName,
  });

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: Text(projectName ?? 'New Project'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: PlanCanvas(
          projectId: projectId,
          initialProjectName: projectName,
        ),
      ),
    );
  }
}
