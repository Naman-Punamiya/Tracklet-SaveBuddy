import 'dart:convert';
import 'package:expense_tracker/constant.dart';
import 'package:expense_tracker/pages/HomePage/Expenses/inside_book_page.dart';
import 'package:expense_tracker/pages/archived_page.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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


  List<dynamic> allBooks = [];
  List<dynamic> filteredBooks = [];

  String get basicAuth =>
      'Basic ${base64Encode(utf8.encode('${widget.email}:${widget.password}'))}';

  @override
  void initState() {
    super.initState();
    _loadBooks();
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

  void filterBooks(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredBooks = List.from(allBooks);
      } else {
        filteredBooks = allBooks.where((book) {
          final name = book["name"].toString().toLowerCase();
          final subtitle = (book["subtitle"] ?? "").toString().toLowerCase();
          query = query.toLowerCase();
          return name.contains(query) || subtitle.contains(query);
        }).toList();
      }
    });
  }

  bool isLoading = true;

  Future<void> _loadBooks() async {
    try {
      allBooks = await fetchBooks();
      filteredBooks = List.from(allBooks);
    } finally {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  void _showAddBookDialog() {
    bookNameController.clear();
    bookSubtitleController.clear();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Add Book"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: bookNameController,
              decoration: const InputDecoration(labelText: 'Book Name'),
            ),
            TextField(
              controller: bookSubtitleController,
              decoration: const InputDecoration(labelText: 'Book Subtitle'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
            },
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);

              await addBook(
                bookNameController.text,
                bookSubtitleController.text,
              );

              if (!mounted) return;

              await _reloadBooks();

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Book Added Successfully")),
              );
            },
            child: const Text("Add"),
          ),
        ],
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

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Edit Book"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: bookNameController,
              decoration: const InputDecoration(labelText: 'Book Name'),
            ),
            TextField(
              controller: bookSubtitleController,
              decoration: const InputDecoration(labelText: 'Book Subtitle'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
            },
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);

              await updateBook(
                id,
                bookNameController.text,
                bookSubtitleController.text,
              );

              if (!mounted) return;

              await _reloadBooks();

              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text("Book Updated")));
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
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
            onPressed: () {
              Navigator.pop(dialogContext);

              _showEditBookDialog(
                item['id'].toString(),
                bookName,
                bookSubtitle,
              );
            },
            child: const Text("Edit"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              showDialog(
                context: context,
                builder: (confirmContext) => AlertDialog(
                  // title: const Text("Add Book"),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Are you sure you want to delete this book?",
                        style: TextStyle(fontSize: 24, color: Colors.black),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(confirmContext);
                      },
                      child: const Text("Cancel"),
                    ),
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(confirmContext);
                        await archiveBook(item['id'].toString());
                        if (!mounted) return;
                        await _reloadBooks();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Book Archived Successfully"),
                          ),
                        );
                      },
                      child: const Text("Archive"),
                    ),
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(confirmContext);
                        await deleteBook(item['id'].toString());
                        if (!mounted) return;
                        await _reloadBooks();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Book Deleted Successfully"),
                          ),
                        );
                      },
                      child: const Text("Delete"),
                    ),
                  ],
                ),
              );
              // await _deleteBook(item['id'].toString(), dialogContext);
            },
            child: const Text("Delete"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
            },
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 100,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "My Books",
              style: const TextStyle(
                fontSize: 30,
                color: Colors.black,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              "Manage and Track all your expenses in one place",
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.archive_outlined,
              color: Colors.black,
              size: 30,
            ),
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
        ],
      ),

      body: buildBody(),

      floatingActionButton: TextButton(
        style: TextButton.styleFrom(
          minimumSize: Size(70, 60),
          maximumSize: Size(160, 60),
          backgroundColor: Colors.deepPurple,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(100),
          ),
        ),
        onPressed: _showAddBookDialog,
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Row(
            children: [
              const Icon(Icons.add, color: Colors.white, size: 30),
              SizedBox(width: 5),
              Text(
                "Add Book",
                style: TextStyle(color: Colors.white, fontSize: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildBody() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Empty State
    if (filteredBooks.isEmpty) {
      return const Center(
        child: Text("No Books Found", style: TextStyle(fontSize: 18)),
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
          child: ListView.builder(
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
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BookInsideHomePage(
                            bookId: item['id'].toString(),
                            bookName: bookName,
                            email: widget.email,
                            password: widget.password,
                          ),
                        ),
                      );
                    },

                    onLongPress: () {
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
    final url = Uri.parse("${bookUrl}readAll");

    final res = await http.get(
      url,
      headers: {'Authorization': basicAuth, 'Content-Type': 'application/json'},
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to load books');
    }

    print("Books fetched: ${res.body}");
    return jsonDecode(res.body);
  }

  Future<void> addBook(String name, String subtitle) async {
    final url = Uri.parse("${bookUrl}create");

    final res = await http.post(
      url,
      headers: {'Authorization': basicAuth, 'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'subtitle': subtitle}),
    );

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Failed to add book');
    }
  }

  Future<void> deleteBook(String id) async {
    final url = Uri.parse("${bookUrl}delete/$id");

    final res = await http.delete(url, headers: {'Authorization': basicAuth});

    if (res.statusCode != 200) {
      throw Exception('Failed to delete book');
    }
  }

  Future<void> updateBook(String id, String name, String subtitle) async {
    final url = Uri.parse("${bookUrl}edit/$id");

    final res = await http.put(
      url,
      headers: {'Authorization': basicAuth, 'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'subtitle': subtitle}),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to update book');
    }
  }

  Future<void> archiveBook(String id) async {
    final url = Uri.parse("${bookUrl}archive/$id");
    final res = await http.patch(url, headers: {'Authorization': basicAuth});
    if (res.statusCode != 200) {
      throw Exception('Failed to archive book');
    }
  }
}
