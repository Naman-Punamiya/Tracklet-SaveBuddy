import 'dart:async';
import 'dart:convert';
import 'package:expense_tracker/core/widgets/app_empty_state.dart';
import 'package:expense_tracker/core/widgets/app_loading.dart';
import 'package:expense_tracker/pages/HomePage/Expenses/category_page.dart';
import 'package:expense_tracker/pages/HomePage/Expenses/inside_book_page.dart';
import 'package:expense_tracker/pages/archived_page.dart';
import 'package:expense_tracker/repositories/repository.dart';
import 'package:expense_tracker/services/connectivity_service.dart';
import 'package:flutter/material.dart';

class BookPage extends StatefulWidget {
  final String email;
  final String password;
  const BookPage({super.key, required this.email, required this.password});

  @override
  State<BookPage> createState() => _BookPageState();
}

class _BookPageState extends State<BookPage> {
  final TextEditingController bookNameController = TextEditingController();
  final TextEditingController bookSubtitleController = TextEditingController();
  final TextEditingController searchController = TextEditingController();
  StreamSubscription<ConnectivityStatus>? _connectivitySubscription;

  final BookRepository bookRepo = BookRepository();

  List<dynamic> allBooks = [];
  List<dynamic> filteredBooks = [];
  bool isLoading = true;

  String get basicAuth =>
      'Basic ${base64Encode(utf8.encode('${widget.email}:${widget.password}'))}';

  @override
  void initState() {
    super.initState();
    _loadBooks();
    _triggerSync();
    _connectivitySubscription = ConnectivityService.connectivityStream.listen((
      status,
    ) {
      if (status != ConnectivityStatus.offline) {
        _triggerSync();
      }
    });
  }

  Future<void> _triggerSync() async {
    await SyncEngine.syncAll(basicAuth);
    if (mounted) {
      _loadBooks();
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    bookNameController.dispose();
    bookSubtitleController.dispose();
    searchController.dispose();
    super.dispose();
  }

  Future<void> _reloadBooks() async {
    setState(() {
      isLoading = true;
    });
    await _loadBooks();
  }

  void filterBooks(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      setState(() {
        filteredBooks = List.from(allBooks);
      });
    } else {
      final results = await bookRepo.searchBooks(trimmedQuery, 0);
      if (!mounted) return;
      setState(() {
        filteredBooks = results;
      });
    }
  }

  Future<void> _loadBooks() async {
    try {
      allBooks = await fetchBooks();
      filteredBooks = List.from(allBooks);
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  IconData _getCategoryIcon(String bookName) {
    final name = bookName.toLowerCase();
    if (name.contains('personal') ||
        name.contains('wallet') ||
        name.contains('cash') ||
        name.contains('money')) {
      return Icons.account_balance_wallet_rounded;
    } else if (name.contains('travel') ||
        name.contains('trip') ||
        name.contains('flight') ||
        name.contains('vacation') ||
        name.contains('tour')) {
      return Icons.flight_takeoff_rounded;
    } else if (name.contains('office') ||
        name.contains('work') ||
        name.contains('business') ||
        name.contains('job')) {
      return Icons.work_outline_rounded;
    } else if (name.contains('college') ||
        name.contains('school') ||
        name.contains('study') ||
        name.contains('education')) {
      return Icons.school_outlined;
    } else if (name.contains('shopping') ||
        name.contains('store') ||
        name.contains('cart') ||
        name.contains('buy') ||
        name.contains('market')) {
      return Icons.shopping_cart_outlined;
    }
    return Icons.menu_book_rounded;
  }

  void _showAddBookDialog() {
    bookNameController.clear();
    bookSubtitleController.clear();
    String? nameError;
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, dialogSetState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: Colors.white,
            title: const Text(
              "Add Book",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: bookNameController,
                  decoration: InputDecoration(
                    labelText: 'Book Name',
                    errorText: nameError,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF3EAD91), width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: bookSubtitleController,
                  decoration: InputDecoration(
                    labelText: 'Book Subtitle',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF3EAD91), width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: Text("Cancel", style: TextStyle(color: Colors.grey.shade600)),
              ),
              ElevatedButton(
                onPressed: () async {
                  final trimmedName = bookNameController.text.trim();
                  if (trimmedName.isEmpty) {
                    dialogSetState(() {
                      nameError = "Book name must not be empty";
                    });
                    return;
                  }

                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(dialogContext);
                  await addBook(trimmedName, bookSubtitleController.text);

                  if (!mounted) return;
                  await _reloadBooks();

                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text("Book Added Successfully"),
                      backgroundColor: Color(0xFF3EAD91),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3EAD91),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text("Add"),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditBookDialog(
    String id,
    String currentBookName,
    String currentBookSubtitle,
  ) {
    bookNameController.text = currentBookName;
    bookSubtitleController.text = currentBookSubtitle;
    String? nameError;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, dialogSetState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: Colors.white,
            title: const Text(
              "Edit Book",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: bookNameController,
                  decoration: InputDecoration(
                    labelText: 'Book Name',
                    errorText: nameError,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF3EAD91), width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: bookSubtitleController,
                  decoration: InputDecoration(
                    labelText: 'Book Subtitle',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF3EAD91), width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: Text("Cancel", style: TextStyle(color: Colors.grey.shade600)),
              ),
              ElevatedButton(
                onPressed: () async {
                  final trimmedName = bookNameController.text.trim();
                  if (trimmedName.isEmpty) {
                    dialogSetState(() {
                      nameError = "Book name must not be empty";
                    });
                    return;
                  }

                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(dialogContext);
                  await updateBook(
                    id,
                    trimmedName,
                    bookSubtitleController.text,
                  );

                  if (!mounted) return;
                  await _reloadBooks();

                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text("Book Updated Successfully"),
                      backgroundColor: Color(0xFF3EAD91),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3EAD91),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text("Save"),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showBookDetails(Map<String, dynamic> item) {
    final String bookName = item['name']?.toString() ?? '';
    final String bookSubtitle = item['subtitle']?.toString() ?? '';
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: const Text(
          "Book Options",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Book Name: $bookName",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            if (bookSubtitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                "Subtitle: $bookSubtitle",
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _showEditBookDialog(
                item['id'].toString(),
                bookName,
                bookSubtitle,
              );
            },
            child: const Text("Edit", style: TextStyle(color: Color(0xFF3EAD91))),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              showDialog(
                context: context,
                builder: (confirmContext) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  backgroundColor: Colors.white,
                  title: const Text(
                    "Manage Book",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  content: const Text(
                    "Choose an action for this expense book:",
                    style: TextStyle(fontSize: 15),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(confirmContext);
                      },
                      child: Text("Cancel", style: TextStyle(color: Colors.grey.shade600)),
                    ),
                    TextButton(
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        Navigator.pop(confirmContext);
                        await archiveBook(item['id'].toString());
                        if (!mounted) return;
                        await _reloadBooks();
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text("Book Archived Successfully"),
                            backgroundColor: Color(0xFF3EAD91),
                          ),
                        );
                      },
                      child: const Text(
                        "Archive",
                        style: TextStyle(color: Colors.orange),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        Navigator.pop(confirmContext);
                        await deleteBook(item['id'].toString());
                        if (!mounted) return;
                        await _reloadBooks();
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text("Book Deleted Successfully"),
                            backgroundColor: Colors.red,
                          ),
                        );
                      },
                      child: const Text(
                        "Delete",
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
            },
            child: const Text("Delete / Archive", style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
            },
            child: Text("Close", style: TextStyle(color: Colors.grey.shade600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        toolbarHeight: 90,
        backgroundColor: const Color(0xFFF9FAFB),
        elevation: 0,
        surfaceTintColor: const Color(0xFFF9FAFB),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "My Books",
              style: TextStyle(
                fontSize: 30,
                color: Colors.grey.shade900,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Manage and track all your expenses in one place",
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 6),
            decoration: const BoxDecoration(
              color: Color(0xFFE8F6F3),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(
                Icons.category_outlined,
                color: Color(0xFF3EAD91),
                size: 22,
              ),
              tooltip: "Manage Categories",
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CategoryPage(
                      email: widget.email,
                      password: widget.password,
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFE8F6F3),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.archive_outlined,
                  color: Color(0xFF3EAD91),
                  size: 22,
                ),
                tooltip: "Archived Books",
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ArchivedBooksPage(
                        email: widget.email,
                        password: widget.password,
                      ),
                    ),
                  );
                  if (result == true) {
                    await _reloadBooks();
                  }
                },
              ),
            ),
          ),
        ],
      ),
      body: buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_book_fab',
        backgroundColor: const Color(0xFF3EAD91),
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        onPressed: _showAddBookDialog,
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
        label: const Text(
          "Add Book",
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  Widget buildBody() {
    if (isLoading) {
      return const AppLoading();
    }

    if (allBooks.isEmpty) {
      return AppEmptyState(
        icon: Icons.menu_book_rounded,
        title: "No Books Yet",
        description: "Create your first expense book and start managing your finances effortlessly.",
        buttonLabel: "Create Book",
        onButtonPressed: _showAddBookDialog,
      );
    }

    return Column(
      children: [
        // Summary Cards Section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0C000000),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          color: Color(0xFFE8F6F3),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.menu_book_rounded,
                          color: Color(0xFF3EAD91),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Total Books",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            "${allBooks.length}",
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.shade900,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CategoryPage(
                          email: widget.email,
                          password: widget.password,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0C000000),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            color: Color(0xFFE8F6F3),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.category_outlined,
                            color: Color(0xFF3EAD91),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Categories",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              "Manage",
                              style: TextStyle(
                                fontSize: 16,
                                color: const Color(0xFF3EAD91),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Search Section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0C000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: searchController,
              onChanged: filterBooks,
              style: TextStyle(fontSize: 15, color: Colors.grey.shade900),
              decoration: InputDecoration(
                hintText: "Search books...",
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF3EAD91), size: 22),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (searchController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 20),
                        color: Colors.grey.shade500,
                        onPressed: () {
                          searchController.clear();
                          filterBooks('');
                        },
                      ),
                    IconButton(
                      icon: const Icon(Icons.mic_rounded, size: 20),
                      color: const Color(0xFF3EAD91),
                      onPressed: () {},
                    ),
                    IconButton(
                      icon: const Icon(Icons.tune_rounded, size: 20),
                      color: const Color(0xFF3EAD91),
                      onPressed: () {},
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Books List Section
        Expanded(
          child: filteredBooks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off_rounded,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "No matching books found",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                  itemCount: filteredBooks.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = filteredBooks[index] as Map<String, dynamic>;
                    final String bookName = item['name']?.toString() ?? 'Unnamed';
                    final String subtitle = item['subtitle']?.toString() ?? '';
                    final IconData catIcon = _getCategoryIcon(bookName);

                    final syncedVal = item['synced'];
                    final int syncedStatus = syncedVal is int
                        ? syncedVal
                        : (syncedVal == true || syncedVal == null ? 1 : 0);

                    return _BookCardItem(
                      key: ValueKey(item['id']),
                      item: item,
                      bookName: bookName,
                      subtitle: subtitle,
                      catIcon: catIcon,
                      syncedStatus: syncedStatus,
                      onTap: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BookInsideHomePage(
                              bookId: item['id'].toString(),
                              bookName: bookName,
                              email: widget.email,
                              password: widget.password,
                            ),
                          ),
                        );
                        if (result == true) {
                          await _reloadBooks();
                        }
                      },
                      onLongPress: () {
                        _showBookDetails(item);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<List<dynamic>> fetchBooks() async {
    return await bookRepo.getBooks(archived: 0);
  }

  Future<void> addBook(String name, String subtitle) async {
    await bookRepo.addBook(name, subtitle, basicAuth);
  }

  Future<void> updateBook(String id, String name, String subtitle) async {
    await bookRepo.updateBook(id, name, subtitle, basicAuth);
  }

  Future<void> archiveBook(String id) async {
    await bookRepo.archiveBook(id, basicAuth);
  }

  Future<void> deleteBook(String id) async {
    await bookRepo.deleteBook(id, basicAuth);
  }
}

class _BookCardItem extends StatefulWidget {
  final Map<String, dynamic> item;
  final String bookName;
  final String subtitle;
  final IconData catIcon;
  final int syncedStatus;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _BookCardItem({
    super.key,
    required this.item,
    required this.bookName,
    required this.subtitle,
    required this.catIcon,
    required this.syncedStatus,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  State<_BookCardItem> createState() => _BookCardItemState();
}

class _BookCardItemState extends State<_BookCardItem> {
  bool isPressed = false;

  Widget _buildSyncBadge(int status) {
    Color bgColor;
    Color textColor;
    IconData icon;
    String text;

    switch (status) {
      case 1:
        bgColor = const Color(0xFFE8F6F3);
        textColor = const Color(0xFF3EAD91);
        icon = Icons.cloud_done_rounded;
        text = "Synced";
        break;
      case 2:
        bgColor = const Color(0xFFFDE8E8);
        textColor = const Color(0xFFEF4444);
        icon = Icons.cloud_off_rounded;
        text = "Sync Failed";
        break;
      case 0:
      default:
        bgColor = const Color(0xFFFEF3C7);
        textColor = const Color(0xFFD97706);
        icon = Icons.cloud_upload_outlined;
        text = "Pending Sync";
        break;
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: Container(
        key: ValueKey<int>(status),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: textColor, size: 13),
            const SizedBox(width: 4),
            Text(
              text,
              style: TextStyle(
                color: textColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: isPressed ? 0.98 : 1.0,
      duration: const Duration(milliseconds: 100),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTapDown: (_) => setState(() => isPressed = true),
          onTapUp: (_) => setState(() => isPressed = false),
          onTapCancel: () => setState(() => isPressed = false),
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          child: Hero(
            tag: 'book-${widget.item['id']}',
            child: Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0C000000),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE8F6F3),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.catIcon,
                      color: const Color(0xFF3EAD91),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.bookName,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade900,
                            letterSpacing: -0.2,
                          ),
                        ),
                        if (widget.subtitle.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.subtitle,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        _buildSyncBadge(widget.syncedStatus),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.grey.shade400,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
