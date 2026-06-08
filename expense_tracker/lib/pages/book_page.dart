import 'dart:convert';
import 'package:expense_tracker/constant.dart';
import 'package:expense_tracker/pages/book_inside_page.dart';
import 'package:expense_tracker/pages/login_page.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class BookPage extends StatefulWidget {
  final int userId;
  final String email;
  final String password;
  const BookPage({
    super.key,
    required this.userId,
    required this.email,
    required this.password,
  });

  @override
  State<BookPage> createState() => _BookPageState();
}

class _BookPageState extends State<BookPage> {
  final TextEditingController bookNameController = TextEditingController();

  late Future<List<dynamic>> _booksFuture;

  String get basicAuth =>
      'Basic ${base64Encode(utf8.encode('${widget.email}:${widget.password}'))}';

  @override
  void initState() {
    super.initState();
    _booksFuture = fetchBooks();
  }

  @override
  void dispose() {
    bookNameController.dispose();
    super.dispose();
  }

  void _reloadBooks() {
    setState(() {
      _booksFuture = fetchBooks();
    });
  }

  void _showAddBookDialog() {
    bookNameController.clear();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Add Book"),
        content: TextField(
          controller: bookNameController,
          decoration: const InputDecoration(labelText: 'Book Name'),
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

              await addBook(bookNameController.text);

              if (!mounted) return;

              _reloadBooks();

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

  void _showEditBookDialog(String id, String currentBookName) {
    bookNameController.text = currentBookName;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Edit Book"),
        content: TextField(
          controller: bookNameController,
          decoration: const InputDecoration(labelText: 'Book Name'),
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

              await updateBook(id, bookNameController.text);

              if (!mounted) return;

              _reloadBooks();

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

  Future<void> _deleteBook(String id, BuildContext dialogContext) async {
    Navigator.pop(dialogContext);

    await deleteBook(id);

    if (!mounted) return;

    _reloadBooks();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Book Deleted")));
  }

  void _showBookDetails(Map<String, dynamic> item) {
    final String bookName = item['name']?.toString() ?? '';

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Book Details"),
        content: Text("Book Name: $bookName"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);

              _showEditBookDialog(item['id'].toString(), bookName);
            },
            child: const Text("Edit"),
          ),
          TextButton(
            onPressed: () async {
              await _deleteBook(item['id'].toString(), dialogContext);
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
        title: Text(
          "My Books",
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),

      body: FutureBuilder<List<dynamic>>(
        future: _booksFuture,
        builder: (context, snapshot) {
          // Loading
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Error
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final items = snapshot.data ?? [];

          // Empty State
          if (items.isEmpty) {
            return const Center(
              child: Text("No Books Found", style: TextStyle(fontSize: 18)),
            );
          }

          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index] as Map<String, dynamic>;

              final bookName = item['name']?.toString() ?? '';

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                child: Card(
                  elevation: 2,
                  color: Colors.black,
                  child: ListTile(
                    trailing: const Icon(Icons.arrow_forward_ios, color: Colors.black),
                    minTileHeight: 80,
                    tileColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: Colors.grey, width: 1),
                    ),
                  
                    title: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text(
                        bookName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
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
          );
        },
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: _showAddBookDialog,
        backgroundColor: Color(0xff54af96),
        child: const Icon(Icons.add, color: Colors.white),
      ),
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

    return jsonDecode(res.body);
  }

  Future<void> addBook(String name) async {
    final url = Uri.parse("${bookUrl}create");

    final res = await http.post(
      url,
      headers: {'Authorization': basicAuth, 'Content-Type': 'application/json'},
      body: jsonEncode({'name': name}),
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

  Future<void> updateBook(String id, String name) async {
    final url = Uri.parse("${bookUrl}edit/$id");

    final res = await http.put(
      url,
      headers: {'Authorization': basicAuth, 'Content-Type': 'application/json'},
      body: jsonEncode({'name': name}),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to update book');
    }
  }

  Future<void> logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    await prefs.clear();

    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => LoginPage()));
  }
}
