import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/database/database.dart';
import '../../core/services/project_service.dart';
import '../../core/export/pdf_export.dart';
import '../canvas/viewport.dart';
import 'editor_screen.dart';

/// Payload for drag-and-drop of projects and folders.
class _DragItem {
  final bool isFolder;
  final int id;
  _DragItem({required this.isFolder, required this.id});
}

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  AppDatabase? _db;
  ProjectService? _projectService;
  List<Project> _projects = [];
  List<Folder> _folders = [];
  final Set<int> _expandedFolderIds = {};
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
      
      await _loadData();
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

  Future<void> _loadData() async {
    if (_projectService == null) {
      debugPrint('ProjectsScreen: _loadData called but _projectService is null');
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
      debugPrint('ProjectsScreen: Loading folders and projects from database...');
      final projects = await _projectService!.getAllProjects();
      final folders = await _projectService!.getFolders();
      debugPrint('ProjectsScreen: Loaded ${projects.length} projects, ${folders.length} folders');
      setState(() {
        _projects = projects;
        _folders = folders;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('ProjectsScreen: Error loading data: $e');
      debugPrint('ProjectsScreen: Stack trace: $stackTrace');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _createFolder({int? parentId}) async {
    if (_projectService == null) return;
    // Defer so the button tap finishes before showing the dialog; prevents
    // the tap from propagating to the barrier and dismissing it immediately.
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    final nameController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(parentId == null ? 'New Folder' : 'New Subfolder'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Folder Name',
            hintText: 'Enter folder name',
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
      try {
        await _projectService!.createFolder(
          name: nameController.text.trim(),
          parentId: parentId,
        );
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Folder "${nameController.text.trim()}" created')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error creating folder: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteFolder(Folder folder) async {
    if (_projectService == null) return;
    final projectsInFolder = _projects.where((p) => p.folderId == folder.id).length;
    final subfolders = _folders.where((f) => f.parentId == folder.id).length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Folder'),
        content: Text(
          'Are you sure you want to delete "${folder.name}"?\n\n'
          '${projectsInFolder > 0 ? "$projectsInFolder project(s) will move to the root. " : ""}'
          '${subfolders > 0 ? "$subfolders subfolder(s) will be deleted. " : ""}'
          'This action cannot be undone.',
        ),
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
        await _projectService!.deleteFolder(folder.id);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Folder "${folder.name}" deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting folder: $e')),
          );
        }
      }
    }
  }

  static const int _rootFolderId = -1;

  Future<void> _moveProjectToFolder(Project project) async {
    if (_projectService == null) return;
    final folderOptions = <int, String>{_rootFolderId: '(Root)'};
    for (final f in _folders) {
      folderOptions[f.id] = f.name;
    }
    final selected = await showDialog<int?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move to Folder'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: folderOptions.entries.map((e) {
              return ListTile(
                title: Text(e.value),
                onTap: () => Navigator.of(context).pop(e.key),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (selected == null) return; // User cancelled
    final targetFolderId = selected == _rootFolderId ? null : selected;
    if (targetFolderId != project.folderId) {
      try {
        await _projectService!.moveProjectToFolder(project.id, targetFolderId);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Project moved')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error moving project: $e')),
          );
        }
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
      final name = nameController.text.trim();
      if (_projectService == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cannot create project: database not ready.')),
          );
        }
        return;
      }
      try {
        // Save empty project immediately so it exists with the chosen name
        final defaultViewport = PlanViewport(
          mmPerPx: 5.0,
          worldOriginMm: const Offset(-500, -500),
        );
        final projectId = await _projectService!.saveProject(
          name: name,
          rooms: [],
          viewport: defaultViewport,
        );
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => EditorScreen(projectId: projectId, projectName: name),
            ),
          ).then((_) => _loadData());
        }
      } catch (e) {
        debugPrint('Error creating project: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving project: $e')),
          );
        }
      }
    }
  }

  Future<void> _openProject(Project project) async {
    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => EditorScreen(projectId: project.id, projectName: project.name),
        ),
      ).then((_) => _loadData()); // Reload projects when returning
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
        await _loadData();
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

  /// True if [folderId] is [ancestorId] or a descendant of it (would create cycle if moved into ancestor).
  bool _isDescendantOf(int folderId, int ancestorId) {
    if (folderId == ancestorId) return true;
    int? current = folderId;
    final seen = <int>{};
    while (current != null && seen.add(current)) {
      Folder? folder;
      for (final f in _folders) {
        if (f.id == current) { folder = f; break; }
      }
      if (folder == null) break;
      if (folder.parentId == ancestorId) return true;
      current = folder.parentId;
    }
    return false;
  }

  static const int _rootTargetId = -1;

  Future<void> _handleDrop(_DragItem item, int? targetFolderId) async {
    if (_projectService == null) return;
    final destFolderId = targetFolderId == _rootTargetId ? null : targetFolderId;
    try {
      if (item.isFolder) {
        if (destFolderId == item.id) return;
        if (destFolderId != null && _isDescendantOf(destFolderId, item.id)) return;
        Folder? folder;
        for (final f in _folders) {
          if (f.id == item.id) { folder = f; break; }
        }
        if (folder != null && folder.parentId == destFolderId) return; // Already there
        await _projectService!.moveFolderToFolder(item.id, destFolderId);
      } else {
        Project? project;
        for (final p in _projects) {
          if (p.id == item.id) { project = p; break; }
        }
        if (project != null && project.folderId == destFolderId) return; // Already there
        await _projectService!.moveProjectToFolder(item.id, destFolderId);
      }
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(item.isFolder ? 'Folder moved' : 'Project moved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  /// Drop zone to move an item up one level (to parent folder or root).
  Widget _buildMoveUpDropZone(int targetFolderId, {bool indent = false}) {
    final isRoot = targetFolderId == _rootTargetId;
    return DragTarget<_DragItem>(
      onAcceptWithDetails: (details) => _handleDrop(details.data, targetFolderId),
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.only(left: indent ? 48 : 24, right: 16, top: 8, bottom: 8),
          margin: const EdgeInsets.only(left: 8, right: 8, bottom: 4),
          decoration: BoxDecoration(
            color: isHovering
                ? Colors.amber.withOpacity(0.2)
                : Colors.grey.withOpacity(0.05),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isHovering ? Colors.amber : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isRoot ? Icons.folder_open : Icons.subdirectory_arrow_left,
                color: isHovering ? Colors.amber : Colors.grey,
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                isRoot ? 'Drop here to move to root' : 'Drop here to move up',
                style: TextStyle(
                  color: isHovering ? Colors.amber.shade800 : Colors.grey,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildFolderTiles(int? parentId) {
    final rootFolders = _folders.where((f) => f.parentId == parentId).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return rootFolders.map((folder) {
      final subfolders = _folders.where((f) => f.parentId == folder.id).toList();
      final projectsInFolder = _projects.where((p) => p.folderId == folder.id).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      final isExpanded = _expandedFolderIds.contains(folder.id);
      final tile = ExpansionTile(
        key: ValueKey('folder-${folder.id}'),
        initiallyExpanded: isExpanded,
        onExpansionChanged: (expanded) {
          setState(() {
            if (expanded) {
              _expandedFolderIds.add(folder.id);
            } else {
              _expandedFolderIds.remove(folder.id);
            }
          });
        },
        leading: const Icon(Icons.folder, size: 32, color: Colors.amber),
        title: Text(folder.name),
        subtitle: Text('${subfolders.length} folder(s), ${projectsInFolder.length} project(s)'),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            PopupMenuItem(
              child: const Row(
                children: [
                  Icon(Icons.create_new_folder),
                  SizedBox(width: 8),
                  Text('New subfolder'),
                ],
              ),
              onTap: () => _createFolder(parentId: folder.id),
            ),
            PopupMenuItem(
              child: const Row(
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete folder'),
                ],
              ),
              onTap: () => _deleteFolder(folder),
            ),
          ],
        ),
        children: [
          _buildMoveUpDropZone(folder.parentId == null ? _rootTargetId : folder.parentId!, indent: true),
          ..._buildFolderTiles(folder.id),
          ...projectsInFolder.map((p) => _buildProjectTile(p, indent: true)),
        ],
      );
      return DragTarget<_DragItem>(
        onWillAcceptWithDetails: (details) {
          if (details.data.isFolder) {
            if (details.data.id == folder.id) return false;
            if (_isDescendantOf(folder.id, details.data.id)) return false;
          }
          return true;
        },
        onAcceptWithDetails: (details) => _handleDrop(details.data, folder.id),
        builder: (context, candidateData, rejectedData) {
          final isHovering = candidateData.isNotEmpty;
          return Draggable<_DragItem>(
            data: _DragItem(isFolder: true, id: folder.id),
            feedback: Material(
              elevation: 4,
              child: Opacity(
                opacity: 0.9,
                child: SizedBox(
                  width: 280,
                  child: ListTile(
                    leading: const Icon(Icons.folder, size: 32, color: Colors.amber),
                    title: Text(folder.name),
                  ),
                ),
              ),
            ),
            childWhenDragging: Opacity(opacity: 0.4, child: tile),
            child: Container(
              decoration: isHovering
                  ? BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    )
                  : null,
              child: tile,
            ),
          );
        },
      );
    }).toList();
  }

  List<Widget> _buildProjectTiles(int? folderId) {
    final list = _projects.where((p) => p.folderId == folderId).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list.map((p) => _buildProjectTile(p)).toList();
  }

  Widget _buildProjectTile(Project project, {bool indent = false}) {
    final tile = ListTile(
      leading: const Icon(Icons.description, size: 32, color: Colors.blue),
      title: Text(project.name),
      subtitle: Text('Updated ${_formatDate(project.updatedAt)}'),
      contentPadding: indent ? const EdgeInsets.only(left: 48, right: 16) : null,
      trailing: PopupMenuButton(
        itemBuilder: (context) => [
          PopupMenuItem(
            child: const Row(
              children: [
                Icon(Icons.picture_as_pdf),
                SizedBox(width: 8),
                Text('Export PDF'),
              ],
            ),
            onTap: () => _exportProjectToPdf(project),
          ),
          PopupMenuItem(
            child: const Row(
              children: [
                Icon(Icons.drive_file_move),
                SizedBox(width: 8),
                Text('Move to folder'),
              ],
            ),
            onTap: () => _moveProjectToFolder(project),
          ),
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
    return Draggable<_DragItem>(
      data: _DragItem(isFolder: false, id: project.id),
      feedback: Material(
        elevation: 4,
        child: Opacity(
          opacity: 0.9,
          child: SizedBox(
            width: 280,
            child: ListTile(
              leading: const Icon(Icons.description, size: 32, color: Colors.blue),
              title: Text(project.name),
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.4, child: tile),
      child: tile,
    );
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

  /// Export a project to PDF.
  Future<void> _exportProjectToPdf(Project project) async {
    if (_projectService == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Database not initialized. Please restart the app.')),
        );
      }
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Load full project data
      final projectModel = await _projectService!.getProject(project.id);
      
      if (projectModel == null) {
        if (mounted) {
          Navigator.of(context).pop(); // Close loading
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Project not found')),
          );
        }
        return;
      }

      // Generate PDF
      final pdfBytes = await PdfExportService.exportToPdf(
        rooms: projectModel.rooms,
        useImperial: projectModel.useImperial,
        projectName: projectModel.name,
        viewport: projectModel.viewportState?.toViewport(),
        includeGrid: false, // Can be made configurable later
      );

      if (!mounted) return;

      // Close loading dialog
      Navigator.of(context).pop();

      // Show PDF preview/share dialog
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
      );
    } catch (e) {
      if (!mounted) return;

      // Close loading dialog
      Navigator.of(context).pop();

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting PDF: $e'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  /// Import a project from PDF (placeholder for future implementation).
  Future<void> _importProject() async {
    if (kIsWeb) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Import is not supported on web. Please use a native platform.'),
            duration: Duration(seconds: 5),
          ),
        );
      }
      return;
    }

    try {
      // Pick PDF file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result == null || result.files.isEmpty) {
        return; // User cancelled
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF import is not yet implemented. This feature will be available in a future update.'),
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error importing project: $e'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
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
            icon: const Icon(Icons.create_new_folder),
            tooltip: 'New Folder',
            onPressed: _isInitializing ? null : () => _createFolder(),
          ),
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Import Project',
            onPressed: _isInitializing ? null : _importProject,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _isInitializing ? null : _loadData,
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
              : _projects.isEmpty && _folders.isEmpty
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
                        'Create your first project or folder to get started',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[500],
                            ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    children: [
                      DragTarget<_DragItem>(
                        onAcceptWithDetails: (details) => _handleDrop(details.data, _rootTargetId),
                        builder: (context, candidateData, rejectedData) {
                          final isHovering = candidateData.isNotEmpty;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isHovering
                                  ? Colors.blue.withOpacity(0.15)
                                  : Colors.grey.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isHovering ? Colors.blue : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.folder_open,
                                  color: isHovering ? Colors.blue : Colors.grey,
                                  size: 28,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Drop here to move to root',
                                  style: TextStyle(
                                    color: isHovering ? Colors.blue : Colors.grey,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      ..._buildFolderTiles(null),
                      ..._buildProjectTiles(null),
                    ],
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
