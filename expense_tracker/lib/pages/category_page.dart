import 'dart:convert';

import 'package:expense_tracker/custom_widgets/CategoryIcon.dart';
import 'package:expense_tracker/constant.dart';
import 'package:expense_tracker/custom_widgets/custom_textfield.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class CategoryPage extends StatefulWidget {
  final String email;
  final String password;
  const CategoryPage({super.key, required this.email, required this.password});

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  final TextEditingController nameController = TextEditingController();

  List<CategoryIcon> categoryIcons = [
    CategoryIcon("Food", Icons.fastfood_outlined),
    CategoryIcon("Transportation", Icons.directions_car_outlined),
    CategoryIcon("Shopping", Icons.shopping_bag_outlined),
    CategoryIcon("Home", Icons.home_outlined),
    CategoryIcon("Receipt", Icons.receipt_long_outlined),

    CategoryIcon("Investment", Icons.trending_up_outlined),
    CategoryIcon("Savings", Icons.account_balance_wallet_outlined),
    CategoryIcon("Utilities", Icons.lightbulb_outline),
    CategoryIcon("Healthcare", Icons.medical_services_outlined),
    CategoryIcon("Gifts", Icons.card_giftcard_outlined),

    CategoryIcon("Travel", Icons.flight_outlined),
    CategoryIcon("Education", Icons.school_outlined),
    CategoryIcon("Pets", Icons.pets_outlined),
    CategoryIcon("Person", Icons.person_outlined),
    CategoryIcon("More", Icons.more_horiz_outlined),
  ];

  CategoryIcon selectedIcon = CategoryIcon("Food", Icons.fastfood);

  late Future<List<dynamic>> _iconsFuture;

  bool isCredit = false;

  String get basicAuth =>
      'Basic ${base64Encode(utf8.encode('${widget.email}:${widget.password}'))}';

  List<dynamic> _allCategories = [];
  List<dynamic> _filteredCategories = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();

    _iconsFuture = fetchCategories();
  }

  @override
  void dispose() {
    nameController.dispose();

    super.dispose();
  }

  // =====================================
  // RELOAD
  // =====================================

  void _reloadCategories() {
    setState(() {
      _iconsFuture = fetchCategories();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        centerTitle: true,
        title: _isSearching
            ? TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: "Search category...",
                  border: InputBorder.none,
                ),
                onChanged: _searchCategories,
              )
            : const Text("Categories", style: TextStyle(color: Colors.black)),
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;

                if (!_isSearching) {
                  _filteredCategories = _allCategories;
                }
              });
            },
            icon: Icon(
              _isSearching ? Icons.close : Icons.search,
              color: Colors.black,
              size: 28,
            ),
          ),
          SizedBox(width: 8),
          IconButton(
            onPressed: () {
              _reloadCategories();
            },
            icon: const Icon(Icons.refresh, color: Colors.black, size: 28),
          ),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _iconsFuture,
        builder: (context, snapshot) {
          if (_allCategories.isEmpty && snapshot.hasData) {
            _allCategories = snapshot.data!;
            _filteredCategories = snapshot.data!;
          }

          final items = _filteredCategories;
          // LOADING
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          // ERROR
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index] as Map<String, dynamic>;
                    final name = item['name']?.toString() ?? '';
                    return Padding(
                      padding: const EdgeInsets.all(8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withValues(alpha: 0.2),
                              spreadRadius: 1,
                              blurRadius: 2,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: ListTile(
                            leading: CircleAvatar(
                              radius: 28,
                              backgroundColor: Colors.grey.shade200,
                              child: Icon(
                                getIconFromName(item['icon']),
                                size: 28,
                              ),
                            ),
                            trailing: Row(
                              // mainAxisAlignment: MainAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  onPressed: () {
                                    _showEditDialog(item);
                                  },
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    color: Colors.black,
                                  ),
                                ),
                                SizedBox(
                                  height: 20,
                                  child: VerticalDivider(
                                    color: Colors.grey.shade400,
                                    thickness: .5,
                                    width: 20,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () async {
                                    await _deleteCategory(
                                      item['id'].toString(),
                                      context,
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                            title: Text(
                              name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
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

      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.deepPurple,

        onPressed: () {
          _showAddCategoryDialog();
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showAddCategoryDialog() {
    nameController.clear();
    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            return AlertDialog(
              title: const Text("Add Category"),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CustomTextfield(
                        textEditingController: nameController,
                        hintText: 'Category Name',
                        icon: Icons.edit,
                        isPassword: false,
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 180,
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 5,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                              ),
                          itemCount: categoryIcons.length,
                          itemBuilder: (context, index) {
                            final icon = categoryIcons[index].icon;
                            final isSelected = selectedIcon.icon == icon;

                            return GestureDetector(
                              onTap: () {
                                dialogSetState(() {
                                  selectedIcon = categoryIcons[index];
                                });
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.grey.shade100,
                                  border: isSelected
                                      ? Border.all(
                                          color: Colors.green,
                                          width: 2,
                                        )
                                      : null,
                                ),
                                child: Icon(
                                  icon,
                                  color: isSelected
                                      ? Colors.green
                                      : Colors.grey.shade700,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
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
                    await addCategory(nameController.text, selectedIcon.name);

                    _reloadCategories();
                  },
                  child: const Text("Add"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditDialog(Map<String, dynamic> item) {
    nameController.text = item['name']?.toString() ?? '';

    showDialog(
      context: context,
      builder: (dialogContext) {
        selectedIcon = categoryIcons.firstWhere(
          (e) => e.name == item['icon'],
          orElse: () => categoryIcons.first,
        );
        return AlertDialog(
          title: const Text("Edit Category"),

          content: StatefulBuilder(
            builder: (context, dialogSetState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: "Category Name",
                    ),
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    height: 180,
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: categoryIcons.map((categoryIcon) {
                        final isSelected =
                            selectedIcon.name == categoryIcon.name;

                        return GestureDetector(
                          onTap: () {
                            dialogSetState(() {
                              selectedIcon = categoryIcon;
                            });
                          },
                          child: CircleAvatar(
                            radius: 22,
                            backgroundColor: isSelected
                                ? Colors.green
                                : Colors.grey.shade200,
                            child: Icon(
                              categoryIcon.icon,
                              color: isSelected ? Colors.white : Colors.black,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              );
            },
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

                await updateCategory(
                  item['id'].toString(),
                  nameController.text,
                  selectedIcon.name,
                );

                if (!mounted) return;

                _reloadCategories();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Category Updated")),
                );
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteCategory(String id, BuildContext dialogContext) async {
    Navigator.pop(dialogContext);

    await deleteCategory(id);

    if (!mounted) return;

    _reloadCategories();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Category Deleted")));
  }

  void _showCategoryDetails(Map<String, dynamic> item) {
    final name = item['name']?.toString() ?? '';
    final icon = item['icon']?.toString() ?? '';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Category Details"),

          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Name: $name"),

              const SizedBox(height: 8),

              Text("Icon: $icon"),
            ],
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);

                _showEditDialog(item);
              },
              child: const Text("Edit"),
            ),

            TextButton(
              onPressed: () async {
                await _deleteCategory(item['id'].toString(), dialogContext);
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
        );
      },
    );
  }

  Future<List<dynamic>> fetchCategories() async {
    final url = Uri.parse('${categoryUrl}readAll');
    final res = await http.get(url, headers: {'Authorization': basicAuth});
    if (res.statusCode != 200) {
      throw Exception('Failed: ${res.statusCode}');
    }
    final data = jsonDecode(res.body) as List<dynamic>;
    _allCategories = data;
    _filteredCategories = data;
    return data;
  }

  Future<void> addCategory(String name, String icon) async {
    final url = Uri.parse('${categoryUrl}create');
    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json', 'Authorization': basicAuth},
      body: jsonEncode({
        'name': name,
        'icon': icon,
        'color': '#000000', // Default color (black)
      }),
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Failed to add category');
    }
  }

  Future<void> updateCategory(String id, String name, String icon) async {
    final url = Uri.parse('${categoryUrl}edit/$id');
    final res = await http.put(
      url,
      headers: {'Content-Type': 'application/json', 'Authorization': basicAuth},
      body: jsonEncode({
        'name': name,
        'icon': icon,
        'color': '#000000', // Default color (black)
      }),
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Failed to update category');
    }
  }

  Future<void> deleteCategory(String id) async {
    final url = Uri.parse('${categoryUrl}delete/$id');

    final res = await http.delete(url, headers: {'Authorization': basicAuth});

    if (res.statusCode != 200) {
      throw Exception('Failed to delete category');
    }
  }

  void _searchCategories(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredCategories = _allCategories;
      } else {
        _filteredCategories = _allCategories.where((category) {
          final name = category['name'].toString().toLowerCase();

          return name.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  IconData? getIconFromName(item) {
    for (var categoryIcon in categoryIcons) {
      if (categoryIcon.name == item) {
        return categoryIcon.icon;
      }
    }
    return Icons.category;
  }
}
