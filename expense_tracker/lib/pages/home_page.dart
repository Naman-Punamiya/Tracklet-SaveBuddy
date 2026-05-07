import 'dart:convert';

import 'package:expense_tracker/constant.dart';
import 'package:expense_tracker/pages/expense_page.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  TextEditingController bookNameController = TextEditingController();

  late Future<List<dynamic>> _booksFuture;

  @override
  void initState() {
    super.initState();
    _booksFuture = fetchBooks();
  }

  void _reloadBooks() {
    setState(() {
      _booksFuture = fetchBooks();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Expense Pages", style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _booksFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: \\${snapshot.error}'));
          }
          final items = snapshot.data ?? [];
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index] as Map<String, dynamic>;
              final bookName = item['name']?.toString() ?? '';
              // final bookEntries = item['description']?.toString() ?? '';
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: ListTile(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ExpensePage(
                          bookId: item['id'].toString(),
                          bookName: bookName,
                        ),
                      ),
                    );
                  },

                  onLongPress: () {
                    showDialog(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: Text("Book Details"),

                        content: Text("Book Name: $bookName"),

                        actions: [
                          Row(
                            children: [
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(dialogContext);

                                  showDialog(
                                    context: context,
                                    builder: (dialogContext) => AlertDialog(
                                      title: Text("Edit Book"),

                                      content: TextField(
                                        controller: bookNameController
                                          ..text = bookName,
                                        decoration: InputDecoration(
                                          labelText: 'Book Name',
                                        ),
                                      ),

                                      actions: [
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(dialogContext);
                                          },
                                          child: Text("Cancel"),
                                        ),

                                        TextButton(
                                          onPressed: () async {
                                            await updateBook(
                                              item['id'].toString(),
                                              bookNameController.text,
                                              "",
                                            );

                                            Navigator.pop(dialogContext);

                                            _reloadBooks();

                                            bookNameController.clear();
                                          },
                                          child: Text("Save"),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                child: Text("Edit"),
                              ),

                              SizedBox(width: 8),

                              TextButton(
                                onPressed: () async {
                                  await deleteBook(item['id'].toString());

                                  Navigator.pop(dialogContext);

                                  _reloadBooks();
                                },
                                child: Text("Delete"),
                              ),

                              TextButton(
                                onPressed: () {
                                  Navigator.pop(dialogContext);
                                },
                                child: Text("Close"),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },

                  tileColor: Colors.grey[200],

                  title: Text(
                    bookName,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                  ),

                  // trailing: Text(
                  //   0.toString(),
                  //   style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                  // ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: Text("Add Book"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: bookNameController,
                    decoration: InputDecoration(labelText: 'Book Name'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: Text("Cancel"),
                ),
                TextButton(
                  onPressed: () async {
                    await addBook(bookNameController.text, 0.toString());
                    Navigator.pop(dialogContext);
                    _reloadBooks();
                    bookNameController.clear();
                  },
                  child: Text("Add"),
                ),
              ],
            ),
          );
        },
        backgroundColor: Colors.blueAccent,
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

Future<List<dynamic>> fetchBooks() async {
  final url = Uri.parse("${bookUrl}readAll");
  final res = await http.get(url);
  if (res.statusCode != 200) {
    throw Exception('Failed to load books');
  }
  return jsonDecode(res.body);
}

Future<void> addBook(String name, String description) async {
  final url = Uri.parse("${bookUrl}create");
  final res = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'name': name}),
  );
  if (res.statusCode != 200 && res.statusCode != 201) {
    throw Exception('Failed to add book');
  }
}

Future<dynamic> deleteBook(String id) async {
  final url = Uri.parse("${bookUrl}delete/$id");
  final res = await http.delete(url);
  if (res.statusCode != 200) {
    throw Exception('Failed to delete book');
  }
  return jsonDecode(res.body);
}

Future<dynamic> updateBook(String id, String name, String description) async {
  final url = Uri.parse("${bookUrl}update/$id");
  final res = await http.put(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'name': name}),
  );
  if (res.statusCode != 200) {
    throw Exception('Failed to update book');
  }
  return jsonDecode(res.body);
}
