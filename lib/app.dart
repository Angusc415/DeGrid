import 'package:flutter/material.dart';
import 'ui/screens/projects_screen.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DeGrid',
      theme: ThemeData(useMaterial3: true),
      home: const ProjectsScreen(),
    );
  }
}