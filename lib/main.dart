import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

// --- Main Application Entry Point ---
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final themeProvider = ThemeProvider();
  await themeProvider.loadTheme();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider(
            create: (context) => TaskProvider()..loadTasks()),
      ],
      child: const MyApp(),
    ),
  );
}

// --- Data Models ---
enum Priority { low, medium, high }

enum FilterType { all, pending, completed }

class SubTask {
  String title;
  bool isDone;

  SubTask({required this.title, this.isDone = false});

  Map<String, dynamic> toJson() => {
        'title': title,
        'isDone': isDone,
      };

  factory SubTask.fromJson(Map<String, dynamic> json) => SubTask(
        title: json['title'],
        isDone: json['isDone'],
      );
}

class Task {
  String title;
  bool isDone;
  Priority priority;
  List<SubTask> subTasks;

  Task({
    required this.title,
    this.isDone = false,
    this.priority = Priority.medium,
    List<SubTask>? subTasks,
  }) : subTasks = subTasks ?? [];

  Map<String, dynamic> toJson() => {
        'title': title,
        'isDone': isDone,
        'priority': priority.index,
        'subTasks': subTasks.map((st) => st.toJson()).toList(),
      };

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        title: json['title'],
        isDone: json['isDone'],
        priority: Priority.values[json['priority'] ?? 1],
        subTasks: (json['subTasks'] as List?)
            ?.map((st) => SubTask.fromJson(st))
            .toList(),
      );
}

// --- State Management (Providers) ---

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt('themeMode') ?? 2; // Default to system
    _themeMode = ThemeMode.values[themeIndex];
    notifyListeners();
  }

  Future<void> _saveTheme() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeMode', _themeMode.index);
  }

  void toggleTheme() {
    _themeMode =
        _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    _saveTheme();
    notifyListeners();
  }

  void setSystemTheme() {
    _themeMode = ThemeMode.system;
    _saveTheme();
    notifyListeners();
  }
}

class TaskProvider with ChangeNotifier {
  final GlobalKey<AnimatedListState> listKey = GlobalKey<AnimatedListState>();
  List<Task> _tasks = [];
  FilterType _filter = FilterType.all;
  bool _sortAscending = true;
  String _searchQuery = '';

  List<Task> get tasks {
    List<Task> filteredTasks;
    switch (_filter) {
      case FilterType.pending:
        filteredTasks = _tasks.where((task) => !task.isDone).toList();
        break;
      case FilterType.completed:
        filteredTasks = _tasks.where((task) => task.isDone).toList();
        break;
      case FilterType.all:
        filteredTasks = _tasks;
        break;
    }

    if (_searchQuery.isNotEmpty) {
      filteredTasks = filteredTasks
          .where((task) =>
              task.title.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

    // Sort by priority
    filteredTasks.sort((a, b) {
      final int priorityComparison = _sortAscending
          ? a.priority.index.compareTo(b.priority.index)
          : b.priority.index.compareTo(a.priority.index);
      if (priorityComparison != 0) return priorityComparison;
      // If priorities are equal, maintain original order (or add another sort criterion)
      return _tasks.indexOf(a).compareTo(_tasks.indexOf(b));
    });

    return filteredTasks;
  }

  FilterType get filter => _filter;
  String get searchQuery => _searchQuery;

  void setFilter(FilterType filter) {
    _filter = filter;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void toggleSortOrder() {
    _sortAscending = !_sortAscending;
    notifyListeners();
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedData =
        jsonEncode(_tasks.map((task) => task.toJson()).toList());
    await prefs.setString('tasks', encodedData);
  }

  Future<void> loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final String? tasksString = prefs.getString('tasks');
    if (tasksString != null) {
      final List<dynamic> decodedData = jsonDecode(tasksString);
      _tasks = decodedData.map((item) => Task.fromJson(item)).toList();
      notifyListeners();
    }
  }

  void addTask(String title, Priority priority) {
    final newTask = Task(title: title, priority: priority);
    _tasks.insert(0, newTask);
    listKey.currentState
        ?.insertItem(0, duration: const Duration(milliseconds: 500));
    _saveTasks();
    notifyListeners();
  }

  void updateTask(int index, String newTitle, Priority newPriority) {
    if (index < 0 || index >= _tasks.length) return;
    _tasks[index].title = newTitle;
    _tasks[index].priority = newPriority;
    _saveTasks();
    notifyListeners();
  }

  void toggleTaskStatus(int index) {
    if (index < 0 || index >= _tasks.length) return;
    _tasks[index].isDone = !_tasks[index].isDone;
    _saveTasks();
    notifyListeners();
  }

  Task? deleteTask(int index) {
    if (index < 0 || index >= _tasks.length) return null;
    final Task deletedTask = _tasks.removeAt(index);
    listKey.currentState?.removeItem(
        index,
        (context, animation) => TaskItem(
            task: deletedTask,
            animation: animation,
            onTapped: () {},
            onToggle: () {}));
    _saveTasks();
    notifyListeners();
    return deletedTask;
  }

  void insertTask(int index, Task task) {
    if (index < 0 || index > _tasks.length) return;
    _tasks.insert(index, task);
    listKey.currentState
        ?.insertItem(index, duration: const Duration(milliseconds: 300));
    _saveTasks();
    notifyListeners();
  }

  void addSubTask(int taskIndex, String subTaskTitle) {
    if (taskIndex < 0 || taskIndex >= _tasks.length) return;
    _tasks[taskIndex].subTasks.add(SubTask(title: subTaskTitle));
    _saveTasks();
    notifyListeners();
  }

  void toggleSubTaskStatus(int taskIndex, int subTaskIndex) {
    if (taskIndex < 0 ||
        taskIndex >= _tasks.length ||
        subTaskIndex < 0 ||
        subTaskIndex >= _tasks[taskIndex].subTasks.length) {
      return;
    }
    _tasks[taskIndex].subTasks[subTaskIndex].isDone =
        !_tasks[taskIndex].subTasks[subTaskIndex].isDone;
    _saveTasks();
    notifyListeners();
  }

  void removeSubTask(int taskIndex, int subTaskIndex) {
    if (taskIndex < 0 ||
        taskIndex >= _tasks.length ||
        subTaskIndex < 0 ||
        subTaskIndex >= _tasks[taskIndex].subTasks.length) {
      return;
    }
    _tasks[taskIndex].subTasks.removeAt(subTaskIndex);
    _saveTasks();
    notifyListeners();
  }
}

// --- Root Application Widget ---
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const Color primarySeedColor = Colors.deepPurple;
    final TextTheme appTextTheme = TextTheme(
      displayLarge: GoogleFonts.oswald(
          fontSize: 57, fontWeight: FontWeight.bold, letterSpacing: -0.5),
      titleLarge: GoogleFonts.robotoCondensed(
          fontSize: 24, fontWeight: FontWeight.w600),
      bodyMedium: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.normal),
      labelLarge: GoogleFonts.roboto(fontSize: 16, fontWeight: FontWeight.bold),
    );

    final ThemeData lightTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
          seedColor: primarySeedColor, brightness: Brightness.light),
      scaffoldBackgroundColor: Colors.grey[100],
      textTheme: appTextTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
        titleTextStyle: GoogleFonts.oswald(
            fontSize: 28, fontWeight: FontWeight.bold, color: primarySeedColor),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primarySeedColor,
        foregroundColor: Colors.white,
        elevation: 8,
        highlightElevation: 12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: primarySeedColor,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle:
              GoogleFonts.roboto(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 8,
        shadowColor: Colors.black.withAlpha(25),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );

    final ThemeData darkTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
          seedColor: primarySeedColor,
          brightness: Brightness.dark,
          surface: Colors.grey[900]!),
      scaffoldBackgroundColor: Colors.grey[900],
      textTheme: appTextTheme.apply(
          bodyColor: Colors.white70, displayColor: Colors.white),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        titleTextStyle: GoogleFonts.oswald(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple.shade200),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: Colors.deepPurple.shade200,
        foregroundColor: Colors.black,
        elevation: 8,
        highlightElevation: 12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.black,
          backgroundColor: Colors.deepPurple.shade200,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle:
              GoogleFonts.roboto(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 10,
        shadowColor: Colors.black.withAlpha(128),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );

    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'ProTask',
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: themeProvider.themeMode,
          home: const MyHomePage(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

// --- Main Home Page Widget ---
class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _isSearching = false;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final taskProvider = Provider.of<TaskProvider>(context);
    final searchController =
        TextEditingController(text: taskProvider.searchQuery);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search tasks...',
                  border: InputBorder.none,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      searchController.clear();
                      taskProvider.setSearchQuery('');
                      setState(() {
                        _isSearching = false;
                      });
                    },
                  ),
                ),
                onChanged: (value) {
                  taskProvider.setSearchQuery(value);
                },
              )
            : const Text('ProTask'),
        actions: [
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                setState(() {
                  _isSearching = true;
                });
              },
            ),
          IconButton(
              icon: Icon(themeProvider.themeMode == ThemeMode.dark
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded),
              onPressed: () => themeProvider.toggleTheme(),
              tooltip: 'Toggle Theme'),
          IconButton(
              icon: const Icon(Icons.sort_by_alpha_rounded),
              onPressed: () => taskProvider.toggleSortOrder(),
              tooltip: 'Sort by Priority'),
          IconButton(
              icon: const Icon(Icons.settings_system_daydream_rounded),
              onPressed: () => themeProvider.setSystemTheme(),
              tooltip: 'Set System Theme'),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: SegmentedButton<FilterType>(
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor:
                    Theme.of(context).colorScheme.primary.withAlpha(51),
                selectedForegroundColor: Theme.of(context).colorScheme.primary,
              ),
              segments: const <ButtonSegment<FilterType>>[
                ButtonSegment(
                    value: FilterType.all,
                    label: Text('All'),
                    icon: Icon(Icons.inbox_rounded)),
                ButtonSegment(
                    value: FilterType.pending,
                    label: Text('Pending'),
                    icon: Icon(Icons.hourglass_empty_rounded)),
                ButtonSegment(
                    value: FilterType.completed,
                    label: Text('Done'),
                    icon: Icon(Icons.check_circle_outline_rounded)),
              ],
              selected: <FilterType>{taskProvider.filter},
              onSelectionChanged: (Set<FilterType> newSelection) {
                taskProvider.setFilter(newSelection.first);
              },
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.surface,
                  Theme.of(context).colorScheme.surface.withAlpha(242),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Consumer<TaskProvider>(
              builder: (context, taskProvider, child) {
                return taskProvider.tasks.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 24),
                            Text('Your task list is empty!',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(color: Colors.grey.shade500)),
                            const SizedBox(height: 8),
                            Text('Tap the "+" button to add a new task.',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(color: Colors.grey.shade600)),
                          ],
                        ),
                      )
                    : AnimationLimiter(
                        child: AnimatedList(
                          key: taskProvider.listKey,
                          initialItemCount: taskProvider.tasks.length,
                          padding: const EdgeInsets.only(top: 130, bottom: 100),
                          itemBuilder: (context, index, animation) {
                            final task = taskProvider.tasks[index];
                            final realIndex =
                                _findTaskIndex(taskProvider, task);
                            return AnimationConfiguration.staggeredList(
                              position: index,
                              duration: const Duration(milliseconds: 375),
                              child: SlideAnimation(
                                verticalOffset: 50.0,
                                child: FadeInAnimation(
                                  child: TaskItem(
                                    task: task,
                                    animation: animation,
                                    onTapped: () => _showEditTaskDialog(
                                        context, realIndex, task),
                                    onToggle: () => taskProvider
                                        .toggleTaskStatus(realIndex),
                                    onDelete: () {
                                      final deletedTask =
                                          taskProvider.deleteTask(realIndex);
                                      if (deletedTask != null) {
                                        ScaffoldMessenger.of(context)
                                          ..removeCurrentSnackBar()
                                          ..showSnackBar(
                                            SnackBar(
                                              content: const Text(
                                                  'Task Permanently Deleted'),
                                              behavior:
                                                  SnackBarBehavior.floating,
                                              action: SnackBarAction(
                                                  label: 'Undo',
                                                  onPressed: () =>
                                                      taskProvider.insertTask(
                                                          realIndex,
                                                          deletedTask)),
                                            ),
                                          );
                                      }
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
          onPressed: () => _showAddTaskDialog(context),
          tooltip: 'Add Task',
          child: const Icon(Icons.add_rounded)),
    );
  }

  int _findTaskIndex(TaskProvider provider, Task task) {
    return provider.tasks.indexWhere(
        (t) => t.title == task.title && t.priority == task.priority);
  }

  void _showAddTaskDialog(BuildContext context) {
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => TaskDialog(
          onSave: (title, priority) => taskProvider.addTask(title, priority)),
    );
  }

  void _showEditTaskDialog(BuildContext context, int index, Task task) {
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => TaskDialog(
        task: task,
        onSave: (title, priority) =>
            taskProvider.updateTask(index, title, priority),
        onAddSubtask: (subtaskTitle) =>
            taskProvider.addSubTask(index, subtaskTitle),
        onToggleSubtask: (subtaskIndex) =>
            taskProvider.toggleSubTaskStatus(index, subtaskIndex),
        onRemoveSubtask: (subtaskIndex) =>
            taskProvider.removeSubTask(index, subtaskIndex),
        taskIndex: index,
      ),
    );
  }
}

// --- Task Item Widget ---
class TaskItem extends StatelessWidget {
  final Task task;
  final Animation<double> animation;
  final VoidCallback onTapped;
  final VoidCallback onToggle;
  final VoidCallback? onDelete;

  const TaskItem(
      {super.key,
      required this.task,
      required this.animation,
      required this.onTapped,
      required this.onToggle,
      this.onDelete});

  String _getPriorityText(Priority priority) =>
      priority.name[0].toUpperCase() + priority.name.substring(1);

  Color _getPriorityColor(BuildContext context, Priority priority) {
    switch (priority) {
      case Priority.high:
        return Colors.red.shade400;
      case Priority.medium:
        return Colors.amber.shade600;
      case Priority.low:
        return Colors.blue.shade400;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizeTransition(
      sizeFactor: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: Dismissible(
        key: UniqueKey(),
        direction: DismissDirection.startToEnd,
        onDismissed: onDelete != null ? (direction) => onDelete!() : null,
        background: Container(
          decoration: BoxDecoration(
              color: Colors.redAccent, borderRadius: BorderRadius.circular(15)),
          margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: const Icon(Icons.delete_forever_rounded,
              color: Colors.white, size: 30),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Card(
            child: InkWell(
              onTap: onTapped,
              borderRadius: BorderRadius.circular(15),
              splashColor: theme.colorScheme.primary.withAlpha(26),
              highlightColor: theme.colorScheme.primary.withAlpha(13),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Transform.scale(
                      scale: 1.3,
                      child: Checkbox(
                        value: task.isDone,
                        onChanged: (bool? value) => onToggle(),
                        shape: const CircleBorder(),
                        side: BorderSide(
                            width: 2, color: theme.colorScheme.outline),
                        activeColor: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        task.title,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                          decoration: task.isDone
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                          color: task.isDone
                              ? Colors.grey.shade500
                              : theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getPriorityColor(context, task.priority)
                            .withAlpha(51),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: _getPriorityColor(context, task.priority),
                            width: 1.5),
                      ),
                      child: Text(
                        _getPriorityText(task.priority),
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _getPriorityColor(context, task.priority)),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- Add/Edit Task Dialog ---
class TaskDialog extends StatefulWidget {
  final Task? task;
  final int? taskIndex;
  final Function(String title, Priority priority) onSave;
  final Function(String subtaskTitle)? onAddSubtask;
  final Function(int subtaskIndex)? onToggleSubtask;
  final Function(int subtaskIndex)? onRemoveSubtask;

  const TaskDialog({
    super.key,
    this.task,
    this.taskIndex,
    required this.onSave,
    this.onAddSubtask,
    this.onToggleSubtask,
    this.onRemoveSubtask,
  });

  @override
  State<TaskDialog> createState() => _TaskDialogState();
}

class _TaskDialogState extends State<TaskDialog> {
  late TextEditingController _titleController;
  late TextEditingController _subtaskController;
  late Priority _selectedPriority;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task?.title ?? '');
    _subtaskController = TextEditingController();
    _selectedPriority = widget.task?.priority ?? Priority.medium;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtaskController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(widget.task == null ? 'Create New Task' : 'Edit Task',
          style: Theme.of(context).textTheme.titleLarge),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Task Description',
                hintText: 'e.g., Buy groceries',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.edit_note_rounded),
              ),
              onSubmitted: (_) => _saveTask(),
            ),
            const SizedBox(height: 24),
            DropdownButtonFormField<Priority>(
              // ignore: deprecated_member_use
              value: _selectedPriority,
              decoration: InputDecoration(
                labelText: 'Priority Level',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.flag_rounded),
              ),
              items: Priority.values.map((Priority priority) {
                return DropdownMenuItem<Priority>(
                  value: priority,
                  child: Text(priority.name[0].toUpperCase() +
                      priority.name.substring(1)),
                );
              }).toList(),
              onChanged: (Priority? newValue) {
                if (newValue != null) {
                  setState(() => _selectedPriority = newValue);
                }
              },
            ),
            if (widget.task != null) const Divider(height: 30),
            if (widget.task != null) _buildSubTaskList(),
            if (widget.task != null) _buildAddSubTaskField(),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _saveTask,
          child: Text(widget.task == null ? 'Add Task' : 'Save Changes'),
        ),
      ],
    );
  }

  Widget _buildSubTaskList() {
    return Consumer<TaskProvider>(
      builder: (context, taskProvider, child) {
        final task = taskProvider.tasks[widget.taskIndex!];
        if (task.subTasks.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child:
                Text('No sub-tasks yet.', style: TextStyle(color: Colors.grey)),
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          itemCount: task.subTasks.length,
          itemBuilder: (context, index) {
            final subtask = task.subTasks[index];
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Checkbox(
                  value: subtask.isDone,
                  onChanged: (val) => widget.onToggleSubtask?.call(index)),
              title: Text(subtask.title,
                  style: TextStyle(
                      decoration:
                          subtask.isDone ? TextDecoration.lineThrough : null)),
              trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () => widget.onRemoveSubtask?.call(index)),
            );
          },
        );
      },
    );
  }

  Widget _buildAddSubTaskField() {
    return TextField(
      controller: _subtaskController,
      decoration: InputDecoration(
        labelText: 'Add a sub-task',
        suffixIcon: IconButton(
          icon: const Icon(Icons.add),
          onPressed: () {
            if (_subtaskController.text.isNotEmpty) {
              widget.onAddSubtask?.call(_subtaskController.text);
              _subtaskController.clear();
            }
          },
        ),
      ),
    );
  }

  void _saveTask() {
    if (_titleController.text.trim().isNotEmpty) {
      widget.onSave(_titleController.text.trim(), _selectedPriority);
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter a task description.'),
            duration: Duration(seconds: 2)),
      );
    }
  }
}
