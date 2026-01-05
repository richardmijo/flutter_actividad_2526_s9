import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // MALA PRACTICA: Variable global de estado en el root widget sin provider
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  // MALA PRACTICA: Lógica de persistencia mezclada directamente en la UI
  void _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    });
  }

  void _toggleTheme(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', value);
    setState(() {
      _isDarkMode = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gestor de Tareas (Caótico)',
      theme: _isDarkMode
          ? ThemeData.dark(useMaterial3: true)
          : ThemeData.light(useMaterial3: true),
      home: HomePage(isDarkMode: _isDarkMode, onThemeChanged: _toggleTheme),
    );
  }
}

class HomePage extends StatefulWidget {
  final bool isDarkMode;
  final Function(bool) onThemeChanged;

  const HomePage({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // MALA PRACTICA: Base de datos abierta directamente en el estado del widget
  Database? _database;
  // MALA PRACTICA: Usar una lista de Mapas en lugar de Modelos tipados
  List<Map<String, dynamic>> _tasks = [];
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initDatabase();
  }

  // MALA PRACTICA: SQL Crudo y apertura de BD dentro de la UI
  Future<void> _initDatabase() async {
    var databasesPath = await getDatabasesPath();
    String path = join(databasesPath, 'my_bad_database.db');

    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute(
          'CREATE TABLE tasks (id INTEGER PRIMARY KEY, title TEXT, description TEXT)',
        );
      },
    );

    _loadTasks();
  }

  Future<void> _loadTasks() async {
    if (_database == null) return;
    // MALA PRACTICA: Query directo en el método de actualización de UI
    final List<Map<String, dynamic>> maps = await _database!.query('tasks');
    setState(() {
      _tasks = maps;
    });
  }

  Future<void> _addTask() async {
    if (_titleController.text.isEmpty) return;

    if (_database != null) {
      // MALA PRACTICA: Insert directo sin capas
      await _database!.insert('tasks', {
        'title': _titleController.text,
        'description': _descController.text,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      _titleController.clear();
      _descController.clear();
      _loadTasks(); // Recargar todo manual
      Navigator.of(context).pop(); // Cerrar diálogo
    }
  }

  Future<void> _deleteTask(int id) async {
    if (_database != null) {
      await _database!.delete('tasks', where: 'id = ?', whereArgs: [id]);
      _loadTasks();
    }
  }

  // UI Mezclada con todo lo demás
  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Nueva Tarea'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Título'),
              ),
              TextField(
                controller: _descController,
                decoration: const InputDecoration(labelText: 'Descripción'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: _addTask,
              child: const Text('Guardar (SQL Directo)'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lista "Espagueti"'),
        actions: [
          Row(
            children: [
              const Icon(Icons.wb_sunny, size: 16),
              Switch(
                value: widget.isDarkMode,
                onChanged: widget.onThemeChanged,
              ),
              const Icon(Icons.nightlight_round, size: 16),
            ],
          ),
        ],
      ),
      body: _tasks.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 60, color: Colors.grey),
                  const SizedBox(height: 10),
                  const Text('No hay tareas ni arquitectura :('),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _tasks.length,
              itemBuilder: (context, index) {
                final task = _tasks[index];
                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    leading: CircleAvatar(child: Text('${task['id']}')),
                    title: Text(task['title']),
                    subtitle: Text(task['description'] ?? ''),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteTask(task['id']),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: Colors.orange,
        child: const Icon(Icons.add),
      ),
    );
  }
}
