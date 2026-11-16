import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'db_init.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initDatabaseFactory();
  runApp(const ReadingChallengeApp());
}

class ReadingChallengeApp extends StatelessWidget {
  const ReadingChallengeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Desafio da Leitura',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          surface: AppColors.surface,
        ),
        fontFamily: 'Source Sans 3',
      ),
      home: const MainNavigation(),
    );
  }
}

class AppColors {
  static const background = Color(0xFFF7F0E5);
  static const surface = Color(0xFFFFFBF5);
  static const primary = Color(0xFF88494B);
  static const darkRed = Color(0xFF6F2E2E);
  static const title = Color(0xFF362D29);
  static const text = Color(0xFF5D5049);
  static const muted = Color(0xFF706158);
  static const border = Color(0xFFDDD0C3);
  static const paleRose = Color(0xFFE6BFB3);
  static const bottomBar = Color(0xFFEADBD2);
  static const success = Color(0xFF45634E);
  static const successBackground = Color(0xFFEDF0E5);
}

class ReadingBook {
  ReadingBook({
    this.id,
    required this.title,
    required this.author,
    required this.totalPages,
    required this.currentPage,
    this.isCompleted = false,
  });

  final int? id;
  final String title;
  final String author;
  final int totalPages;
  int currentPage;
  bool isCompleted;

  double get progress =>
      totalPages <= 0 ? 0.0 : (currentPage / totalPages).clamp(0.0, 1.0);

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'author': author,
      'totalPages': totalPages,
      'currentPage': currentPage,
      'isCompleted': isCompleted ? 1 : 0,
    };
  }

  factory ReadingBook.fromMap(Map<String, dynamic> map) {
    return ReadingBook(
      id: map['id'] as int?,
      title: map['title'] as String,
      author: map['author'] as String,
      totalPages: map['totalPages'] as int,
      currentPage: map['currentPage'] as int,
      isCompleted: (map['isCompleted'] as int) == 1,
    );
  }
}

class DatabaseHelper {
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

Future<Database> _initDatabase() async {
  // Na web, o caminho é só o nome do banco (fica no armazenamento do navegador).
  if (kIsWeb) {
    return await openDatabase(
      'reading_challenge.db',
      version: 1,
      onCreate: _onCreate,
    );
  }

  final dbPath = await getDatabasesPath();
  final path = p.join(dbPath, 'reading_challenge.db');

  return await openDatabase(path, version: 1, onCreate: _onCreate);
}

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE books (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        author TEXT NOT NULL,
        totalPages INTEGER NOT NULL,
        currentPage INTEGER NOT NULL,
        isCompleted INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        id INTEGER PRIMARY KEY,
        annualGoal INTEGER NOT NULL
      )
    ''');

    await db.insert('settings', {'id': 1, 'annualGoal': 24});
  }

  Future<int> getAnnualGoal() async {
    final db = await database;
    final maps = await db.query('settings', where: 'id = ?', whereArgs: [1]);
    if (maps.isNotEmpty) {
      return maps.first['annualGoal'] as int;
    }
    return 0;
  }

  Future<void> updateAnnualGoal(int goal) async {
    final db = await database;
    await db.update(
      'settings',
      {'annualGoal': goal},
      where: 'id = ?',
      whereArgs: [1],
    );
  }

  Future<List<ReadingBook>> getAllBooks() async {
    final db = await database;
    final maps = await db.query('books', orderBy: 'id DESC');
    return maps.map((map) => ReadingBook.fromMap(map)).toList();
  }

  Future<int> getCompletedBooksCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as total FROM books WHERE isCompleted = 1',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> insertBook(ReadingBook book) async {
    final db = await database;
    return await db.insert('books', book.toMap());
  }

  Future<void> updateBook(ReadingBook book) async {
    final db = await database;
    await db.update(
      'books',
      book.toMap(),
      where: 'id = ?',
      whereArgs: [book.id],
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  int _readingGoal = 0;
  int _completedBooks = 0;
  List<ReadingBook> _books = [];
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadDataFromDatabase();
  }

  Future<void> _loadDataFromDatabase() async {
    try {
      final db = DatabaseHelper.instance;
      final goal = await db.getAnnualGoal();
      final books = await db.getAllBooks();
      final completedCount = await db.getCompletedBooksCount();

      if (mounted) {
        setState(() {
          _readingGoal = goal;
          _books = books;
          _completedBooks = completedCount;
          _loadError = null;
          _isLoading = false;
        });
      }
    } catch (e, stack) {
      debugPrint('Erro ao carregar dados: $e');
      debugPrint('$stack');
      if (mounted) {
        setState(() {
          _loadError = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateGoal(int goal) async {
    await DatabaseHelper.instance.updateAnnualGoal(goal);
    await _loadDataFromDatabase();
  }

  Future<void> _updateBookProgress(ReadingBook book, int page) async {
    book.currentPage = page.clamp(0, book.totalPages).toInt();
    book.isCompleted = book.currentPage >= book.totalPages;

    await DatabaseHelper.instance.updateBook(book);
    await _loadDataFromDatabase();
  }

  Future<void> _addBook() async {
    final titleController = TextEditingController();
    final authorController = TextEditingController();
    final pagesController = TextEditingController();

    final result = await showDialog<ReadingBook>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Adicionar livro'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Título'),
                ),
                TextField(
                  controller: authorController,
                  decoration: const InputDecoration(labelText: 'Autor'),
                ),
                TextField(
                  controller: pagesController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Total de páginas',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final pages = int.tryParse(pagesController.text.trim());
                final title = titleController.text.trim();
                final author = authorController.text.trim();

                if (title.isEmpty ||
                    author.isEmpty ||
                    pages == null ||
                    pages <= 0) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Informe título, autor e um total de páginas válido (> 0).',
                      ),
                    ),
                  );
                  return;
                }

                Navigator.pop(
                  dialogContext,
                  ReadingBook(
                    title: title,
                    author: author,
                    totalPages: pages,
                    currentPage: 0,
                  ),
                );
              },
              child: const Text('Adicionar'),
            ),
          ],
        );
      },
    );

    titleController.dispose();
    authorController.dispose();
    pagesController.dispose();

    if (result != null && mounted) {
      await DatabaseHelper.instance.insertBook(result);
      await _loadDataFromDatabase();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Livro adicionado à biblioteca.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_loadError != null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                    color: AppColors.darkRed,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Não foi possível abrir o banco de dados.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.title,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _loadError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      setState(() => _isLoading = true);
                      _loadDataFromDatabase();
                    },
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final pages = [
      ProfileScreen(
        readingGoal: _readingGoal,
        completedBooks: _completedBooks,
        onSaveGoal: _updateGoal,
      ),
      LibraryScreen(
        books: _books,
        onUpdateProgress: _updateBookProgress,
        onAddBook: _addBook,
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(index: _selectedIndex, children: pages),
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: AppColors.bottomBar,
        indicatorColor: AppColors.primary,
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Meu perfil',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Biblioteca',
          ),
        ],
      ),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.readingGoal,
    required this.completedBooks,
    required this.onSaveGoal,
  });

  final int readingGoal;
  final int completedBooks;
  final ValueChanged<int> onSaveGoal;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _goalController;

  @override
  void initState() {
    super.initState();
    _goalController = TextEditingController(
      text: widget.readingGoal.toString(),
    );
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.readingGoal != widget.readingGoal &&
        _goalController.text != widget.readingGoal.toString()) {
      _goalController.text = widget.readingGoal.toString();
    }
  }

  @override
  void dispose() {
    _goalController.dispose();
    super.dispose();
  }

  void _saveGoal() {
    final goal = int.tryParse(_goalController.text.trim()) ?? 0;

    widget.onSaveGoal(goal);
    FocusScope.of(context).unfocus();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Meta de leitura atualizada.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double progress = widget.readingGoal <= 0
        ? 0.0
        : (widget.completedBooks / widget.readingGoal).clamp(0.0, 1.0);

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: AppColors.paleRose,
              child: const Text(
                'UA',
                style: TextStyle(
                  color: AppColors.darkRed,
                  fontSize: 21,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Text(
                'Usuário A',
                style: TextStyle(
                  color: AppColors.title,
                  fontSize: 25,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 26),
        _AnnualProgressCard(
          completedBooks: widget.completedBooks,
          goal: widget.readingGoal,
          progress: progress,
        ),
        const SizedBox(height: 26),
        const Text(
          'Sua meta de leitura',
          style: TextStyle(
            color: AppColors.title,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Quantos livros deseja ler este ano?',
          style: TextStyle(color: AppColors.text, fontSize: 14),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _goalController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surface,
            suffixText: 'livros',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Altere a sua meta quando quiser.',
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 50,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _saveGoal,
            child: const Text('Salvar meta'),
          ),
        ),
      ],
    );
  }
}

class _AnnualProgressCard extends StatelessWidget {
  const _AnnualProgressCard({
    required this.completedBooks,
    required this.goal,
    required this.progress,
  });

  final int completedBooks;
  final int goal;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final percentage = goal <= 0 ? 0 : (progress * 100).round();

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progresso anual',
                style: TextStyle(
                  color: Color(0xFFFFF8EF),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '2026',
                style: TextStyle(color: Color(0xFFFFF8EF), fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$completedBooks',
                style: const TextStyle(
                  color: Color(0xFFFFF8EF),
                  fontSize: 42,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '/ $goal livros lidos',
                    style: const TextStyle(
                      color: Color(0xFFFFF8EF),
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.paleRose,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$percentage%',
                  style: const TextStyle(
                    color: AppColors.darkRed,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: AppColors.darkRed,
              valueColor: const AlwaysStoppedAnimation(AppColors.paleRose),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            goal <= 0
                ? 'Defina uma meta anual maior que zero.'
                : percentage >= 100
                ? 'Meta alcançada. Parabéns!'
                : percentage >= 50
                ? 'Metade do caminho, continue assim.'
                : 'Continue lendo para alcançar sua meta.',
            style: const TextStyle(color: Color(0xFFFFF8EF), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({
    super.key,
    required this.books,
    required this.onUpdateProgress,
    required this.onAddBook,
  });

  final List<ReadingBook> books;
  final void Function(ReadingBook book, int page) onUpdateProgress;
  final VoidCallback onAddBook;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: onAddBook,
        child: const Icon(Icons.add),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Desafio da Leitura',
                  style: TextStyle(
                    color: AppColors.darkRed,
                    fontSize: 21,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Minha biblioteca',
                  style: TextStyle(
                    color: AppColors.title,
                    fontSize: 25,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'SEUS LIVROS',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      '${books.length} ${books.length == 1 ? 'livro' : 'livros'}',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
          Expanded(
            child: books.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 36),
                      child: Text(
                        'Sua biblioteca ainda está vazia.',
                        style: TextStyle(color: AppColors.muted, fontSize: 14),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
                    itemCount: books.length,
                    itemBuilder: (context, index) {
                      final book = books[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _BookCard(
                          book: book,
                          onUpdateProgress: (page) =>
                              onUpdateProgress(book, page),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _BookCard extends StatelessWidget {
  const _BookCard({required this.book, required this.onUpdateProgress});

  final ReadingBook book;
  final ValueChanged<int> onUpdateProgress;

  Future<void> _editProgress(BuildContext context) async {
    final controller = TextEditingController(text: book.currentPage.toString());

    final page = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Atualizar leitura'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: 'Página atual',
            helperText: 'Total do livro: ${book.totalPages} páginas',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text.trim()) ?? 0;

              if (value > book.totalPages) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Erro: A página atual ($value) não pode ser maior que o total de páginas (${book.totalPages}).',
                    ),
                    backgroundColor: AppColors.darkRed,
                  ),
                );
                return;
              }

              Navigator.pop(dialogContext, value);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    controller.dispose();
    if (page != null) onUpdateProgress(page);
  }

  @override
  Widget build(BuildContext context) {
    final completed = book.isCompleted;
    final progress = book.progress;
    final percentage = (progress * 100).round();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  book.title,
                  style: const TextStyle(
                    color: AppColors.title,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Atualizar progresso',
                onPressed: () => _editProgress(context),
                icon: const Icon(Icons.edit_outlined, size: 20),
                color: AppColors.muted,
              ),
            ],
          ),
          Text(
            book.author,
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  completed ? 'Concluído' : 'Em leitura',
                  style: TextStyle(
                    color: completed ? AppColors.success : AppColors.darkRed,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                '$percentage%',
                style: TextStyle(
                  color: completed ? AppColors.success : AppColors.darkRed,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: AppColors.bottomBar,
              valueColor: AlwaysStoppedAnimation(
                completed ? const Color(0xFF667F65) : AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${book.currentPage} de ${book.totalPages} páginas',
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _editProgress(context),
              icon: const Icon(Icons.bookmark_added_outlined, size: 18),
              label: const Text('Atualizar páginas'),
            ),
          ),
        ],
      ),
    );
  }
}
