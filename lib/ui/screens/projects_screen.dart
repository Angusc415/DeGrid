import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import '../../core/database/database.dart';
import '../../core/services/project_service.dart';
import 'editor_screen.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  AppDatabase? _db;
  ProjectService? _projectService;
  List<Project> _projects = [];
  bool _isLoading = true;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _initializeDatabase();
  }

  Future<void> _initializeDatabase() async {
    try {
      debugPrint('ProjectsScreen: Initializing database...');
      
      // Check if we're on web
      if (kIsWeb) {
        debugPrint('ProjectsScreen: Running on web - database not supported');
        setState(() {
          _isInitializing = false;
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Database is not supported on web.\n'
                'Please run on iOS, Android, macOS, Windows, or Linux for full functionality.',
              ),
              duration: Duration(seconds: 8),
            ),
          );
        }
        return;
      }
      
      _db = AppDatabase();
      _projectService = ProjectService(_db!);
      debugPrint('ProjectsScreen: Database and service created');
      
      // Pre-initialize the database connection
      try {
        await _db!.customSelect('SELECT 1', readsFrom: {}).get();
        debugPrint('ProjectsScreen: Database connection established');
      } catch (e) {
        debugPrint('ProjectsScreen: Warning - Could not pre-initialize connection: $e');
        // Connection will be established on first real query
      }
      
      setState(() {
        _isInitializing = false;
      });
      debugPrint('ProjectsScreen: Initialization complete, loading projects...');
      
      await _loadProjects();
    } catch (e, stackTrace) {
      debugPrint('ProjectsScreen: Error initializing database: $e');
      debugPrint('ProjectsScreen: Stack trace: $stackTrace');
      setState(() {
        _isInitializing = false;
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error initializing database: $e'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _loadProjects() async {
    if (_projectService == null) {
      debugPrint('ProjectsScreen: _loadProjects called but _projectService is null');
      // Wait for initialization to complete (max 5 seconds)
      int waitCount = 0;
      const maxWait = 50; // 50 * 100ms = 5 seconds
      while (_isInitializing && waitCount < maxWait) {
        await Future.delayed(const Duration(milliseconds: 100));
        waitCount++;
      }
      
      if (_projectService == null) {
        debugPrint('ProjectsScreen: _projectService still null after waiting');
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Database not initialized. Please check the console for errors.'),
              duration: Duration(seconds: 5),
            ),
          );
        }
        return;
      }
    }
    
    setState(() {
      _isLoading = true;
    });

    try {
      debugPrint('ProjectsScreen: Loading projects from database...');
      final projects = await _projectService!.getAllProjects();
      debugPrint('ProjectsScreen: Loaded ${projects.length} projects');
      setState(() {
        _projects = projects;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('ProjectsScreen: Error loading projects: $e');
      debugPrint('ProjectsScreen: Stack trace: $stackTrace');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading projects: $e'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _createNewProject() async {
    final nameController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Project'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Project Name',
            hintText: 'Enter project name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (confirmed == true && nameController.text.trim().isNotEmpty) {
      // Navigate to editor with new project
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => EditorScreen(projectId: null, projectName: nameController.text.trim()),
          ),
        ).then((_) => _loadProjects()); // Reload projects when returning
      }
    }
  }

  Future<void> _openProject(Project project) async {
    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => EditorScreen(projectId: project.id, projectName: project.name),
        ),
      ).then((_) => _loadProjects()); // Reload projects when returning
    }
  }

  Future<void> _deleteProject(Project project) async {
    if (_projectService == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Database not initialized. Please restart the app.')),
        );
      }
      return;
    }
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Project'),
        content: Text('Are you sure you want to delete "${project.name}"?\n\nThis action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _projectService!.deleteProject(project.id);
        await _loadProjects();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Project "${project.name}" deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting project: $e')),
          );
        }
      }
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
  }

  @override
  void dispose() {
    _db?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Projects'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _isInitializing ? null : _loadProjects,
          ),
        ],
      ),
      body: _isInitializing
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Initializing database...'),
                ],
              ),
            )
          : _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _projects.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.folder_open,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No projects yet',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create your first project to get started',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[500],
                            ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadProjects,
                  child: ListView.builder(
                    itemCount: _projects.length,
                    itemBuilder: (context, index) {
                      final project = _projects[index];
                      return ListTile(
                        leading: const Icon(Icons.folder, size: 40),
                        title: Text(project.name),
                        subtitle: Text('Updated ${_formatDate(project.updatedAt)}'),
                        trailing: PopupMenuButton(
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              child: const Row(
                                children: [
                                  Icon(Icons.delete, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Delete'),
                                ],
                              ),
                              onTap: () => _deleteProject(project),
                            ),
                          ],
                        ),
                        onTap: () => _openProject(project),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewProject,
        icon: const Icon(Icons.add),
        label: const Text('New Project'),
      ),
    );
  }
}
