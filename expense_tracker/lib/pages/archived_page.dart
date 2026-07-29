import 'dart:convert';
import 'package:expense_tracker/repositories/repository.dart';
import 'package:flutter/material.dart';

class ArchivedBooksPage extends StatefulWidget {
  final String email;
  final String password;
  const ArchivedBooksPage({
    super.key,
    required this.email,
    required this.password,
  });

  @override
  State<ArchivedBooksPage> createState() => _ArchivedBooksPageState();
}

class _ArchivedBooksPageState extends State<ArchivedBooksPage> {
  final TextEditingController bookNameController = TextEditingController();
  final TextEditingController bookSubtitleController = TextEditingController();
  final TextEditingController searchController = TextEditingController();

  final BookRepository bookRepo = BookRepository();

  List<dynamic> allBooks = [];
  List<dynamic> filteredBooks = [];
  bool hasChanges = false;
  bool isLoading = true;

  String get basicAuth =>
      'Basic ${base64Encode(utf8.encode('${widget.email}:${widget.password}'))}';

  @override
  void initState() {
    super.initState();
    _loadBooks();
    _triggerSync();
  }

  Future<void> _triggerSync() async {
    await SyncEngine.syncAll(basicAuth);
    if (mounted) {
      _loadBooks();
    }
  }

  @override
  void dispose() {
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

  void filterBooks(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      setState(() {
        filteredBooks = List.from(allBooks);
      });
    } else {
      final results = await bookRepo.searchBooks(trimmedQuery, 1);
      if (!mounted) return;
      setState(() {
        filteredBooks = results;
      });
    }
  }

  void _showBookDetails(Map<String, dynamic> item) {
    final String bookName = item['name']?.toString() ?? '';
    final String bookSubtitle = item['subtitle']?.toString() ?? '';
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Book Details"),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Book Name: $bookName"),
            Text("Book Subtitle: $bookSubtitle"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await restoreBook(item['id'].toString());
              hasChanges = true;
              await _reloadBooks();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Book Restored Successfully")),
              );
            },
            child: const Text("Restore"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await deleteBook(item['id'].toString());
              hasChanges = true;
              await _reloadBooks();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Book Deleted Successfully")),
              );
            },
            child: const Text("Delete"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
            },
            child: const Text("Cancel"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.pop(context, hasChanges);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 100,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Archived Books",
                style: const TextStyle(
                  fontSize: 30,
                  color: Colors.black,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
              "Manage and Track Your Archived Books",
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
              ),
            ],
          ),
        ),

        body: buildBody(),
      ),
    );
  }

  Widget buildBody() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // CASE 1: There are NO books in the database at all
    if (allBooks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.book_outlined,
              size: 90,
              color: Colors.deepPurple.shade200,
            ),
            const SizedBox(height: 10),
            const Text(
              "No Books Yet",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              "Create your first book.",
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(10.0),
          child: TextField(
            onChanged: filterBooks,
            controller: searchController,
            obscureText: false,
            decoration: InputDecoration(
              hintText: 'Search books...',
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 15),

              filled: true,
              fillColor: Colors.white,

              prefixIcon: Container(
                margin: const EdgeInsets.only(left: 16, right: 8),
                child: Icon(Icons.search, color: Colors.grey, size: 26),
              ),

              contentPadding: const EdgeInsets.symmetric(
                vertical: 18,
                horizontal: 16,
              ),

              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
              ),

              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.grey, width: 1.5),
              ),
            ),
          ),
        ),
        Expanded(
          child: filteredBooks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off_rounded,
                        size: 90,
                        color: Colors.deepPurple.shade200,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "No Books Found",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        "Try another search.",
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: filteredBooks.length,
            itemBuilder: (context, index) {
              final item = filteredBooks[index] as Map<String, dynamic>;
              final bookName = item['name']?.toString() ?? '';
              final bookSubtitle = item['subtitle']?.toString() ?? '';
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10.0,
                  vertical: 4.0,
                ),
                child: Card(
                  child: ListTile(
                    trailing: const Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.black,
                    ),
                    minTileHeight: 100,
                    tileColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: Colors.grey, width: 1),
                    ),
                    title: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: Text(
                        bookName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: Text(
                        bookSubtitle,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    onTap: () {
                      _showBookDetails(item);
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<List<dynamic>> fetchBooks() async {
    return await bookRepo.getBooks(archived: 1);
  }

  Future<void> deleteBook(String id) async {
    await bookRepo.deleteBook(id, basicAuth);
  }

  Future<void> restoreBook(String id) async {
    await bookRepo.restoreBook(id, basicAuth);
  }
}
