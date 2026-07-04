import 'dart:convert';
import 'package:expense_tracker/constant.dart';
import 'package:expense_tracker/custom_widgets/custom_textfield.dart';
import 'package:expense_tracker/pages/HomePage/Expenses/inside_book_page.dart';
import 'package:expense_tracker/pages/Auth/login_page.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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
    searchController.dispose();
    super.dispose();
  }

  void _reloadBooks() {
    setState(() {
      _booksFuture = fetchBooks();
    });
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

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: CustomTextfield(
                  textEditingController: searchController,
                  hintText: 'Search books...',
                  icon: Icons.search,
                  isPassword: false,
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index] as Map<String, dynamic>;

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
                            side: const BorderSide(
                              color: Colors.grey,
                              width: 1,
                            ),
                          ),
                          title: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4.0,
                            ),
                            child: Text(
                              bookName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 24,
                              ),
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4.0,
                            ),
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
        },
      ),

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

  Future<void> _deleteBook(String id, BuildContext dialogContext) async {
    Navigator.pop(dialogContext);

    await deleteBook(id);

    if (!mounted) return;

    _reloadBooks();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Book Deleted")));
  }

  Future<void> deleteBook(String id) async {
    final url = Uri.parse("${bookUrl}delete/$id");

    final res = await http.delete(url, headers: {'Authorization': basicAuth});

    // if (res.statusCode != 200) {
    //   throw Exception('Failed to delete book');
    // }
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
    // if (res.statusCode != 200) {
    //   throw Exception('Failed to archive book');
    // }
  }

  Future<void> restoreBook(String id) async {
    final url = Uri.parse("${bookUrl}restore/$id");
    final res = await http.patch(url, headers: {'Authorization': basicAuth});
    // if (res.statusCode != 200) {
    //   throw Exception('Failed to restore book');
    // }
  }

  Future<void> logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    await prefs.clear();

    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => LoginPage()));
  }
}
