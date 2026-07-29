import 'dart:async';
import 'dart:convert';

import 'package:expense_tracker/core/theme/app_text_theme.dart';
import 'package:expense_tracker/core/widgets/app_empty_state.dart';
import 'package:expense_tracker/core/widgets/app_loading.dart';
import 'package:expense_tracker/custom_widgets/category_icon.dart';
import 'package:expense_tracker/repositories/repository.dart';
import 'package:expense_tracker/services/connectivity_service.dart';
import 'package:flutter/material.dart';

class CategoryPage extends StatefulWidget {
  final String email;
  final String password;
  const CategoryPage({super.key, required this.email, required this.password});

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController searchController = TextEditingController();
  StreamSubscription<ConnectivityStatus>? _connectivitySubscription;

  List<CategoryIcon> categoryIcons = [
    CategoryIcon("Food", Icons.fastfood_rounded),
    CategoryIcon("Transportation", Icons.directions_car_rounded),
    CategoryIcon("Shopping", Icons.shopping_bag_rounded),
    CategoryIcon("Home", Icons.home_rounded),
    CategoryIcon("Receipt", Icons.receipt_long_rounded),
    CategoryIcon("Investment", Icons.trending_up_rounded),
    CategoryIcon("Savings", Icons.account_balance_wallet_rounded),
    CategoryIcon("Utilities", Icons.lightbulb_outline_rounded),
    CategoryIcon("Healthcare", Icons.medical_services_rounded),
    CategoryIcon("Gifts", Icons.card_giftcard_rounded),
    CategoryIcon("Travel", Icons.flight_rounded),
    CategoryIcon("Education", Icons.school_rounded),
    CategoryIcon("Pets", Icons.pets_rounded),
    CategoryIcon("Person", Icons.person_rounded),
    CategoryIcon("More", Icons.more_horiz_rounded),
  ];

  CategoryIcon selectedIcon = CategoryIcon("Food", Icons.fastfood_rounded);
  late Future<List<dynamic>> _iconsFuture;

  String get basicAuth =>
      'Basic ${base64Encode(utf8.encode('${widget.email}:${widget.password}'))}';

  final CategoryRepository categoryRepo = CategoryRepository();

  List<dynamic> _allCategories = [];
  List<dynamic> _filteredCategories = [];
  bool _isSearching = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _iconsFuture = fetchCategories();
    _triggerSync();
    _connectivitySubscription = ConnectivityService.connectivityStream.listen((status) {
      if (status != ConnectivityStatus.offline) {
        _triggerSync();
      }
    });
  }

  Future<void> _triggerSync() async {
    await SyncEngine.syncAll(basicAuth);
    if (mounted) {
      _reloadCategories();
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    nameController.dispose();
    searchController.dispose();
    super.dispose();
  }

  void _reloadCategories() {
    if (!mounted) return;
    setState(() {
      _allCategories = [];
      _filteredCategories = [];
      _iconsFuture = fetchCategories();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFF9FAFB),
        surfaceTintColor: const Color(0xFFF9FAFB),
        titleSpacing: 16,
        title: _isSearching
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: TextField(
                  controller: searchController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: "Search categories...",
                    border: InputBorder.none,
                  ),
                  onChanged: _searchCategories,
                ),
              )
            : Text(
                "Category Management",
                style: TextStyle(
                  color: Colors.grey.shade900,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                ),
              ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 6),
            decoration: const BoxDecoration(
              color: Color(0xFFE8F6F3),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              iconSize: 20,
              tooltip: "Search",
              onPressed: () {
                setState(() {
                  _isSearching = !_isSearching;
                  if (!_isSearching) {
                    searchController.clear();
                    _filteredCategories = List.from(_allCategories);
                  }
                });
              },
              icon: Icon(
                _isSearching ? Icons.close_rounded : Icons.search_rounded,
                color: const Color(0xFF3EAD91),
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFE8F6F3),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              iconSize: 20,
              tooltip: "Refresh",
              onPressed: _reloadCategories,
              icon: const Icon(Icons.refresh_rounded, color: Color(0xFF3EAD91)),
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _iconsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoading();
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: AppTextTheme.bodyMedium,
              ),
            );
          }

          if (_allCategories.isEmpty && snapshot.hasData) {
            _allCategories = List<dynamic>.from(snapshot.data!);
            final query = searchController.text.trim();
            if (query.isEmpty) {
              _filteredCategories = List<dynamic>.from(_allCategories);
            }
          }

          final items = _filteredCategories;

          if (items.isEmpty) {
            if (_allCategories.isNotEmpty) {
              return const AppEmptyState(
                icon: Icons.search_off_rounded,
                title: "No matching categories",
                description: "Try another search keyword.",
              );
            }

            return AppEmptyState(
              icon: Icons.category_outlined,
              title: "No Categories Yet",
              description: "Create custom categories to organize your expenses effortlessly.",
              buttonLabel: "Create Category",
              onButtonPressed: _showAddCategoryDialog,
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            physics: const BouncingScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = items[index] as Map<String, dynamic>;
              final name = item['name']?.toString() ?? '';
              final iconData = getIconFromName(item['icon']);

              return Container(
                padding: const EdgeInsets.all(12),
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
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE8F6F3),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      iconData,
                      color: const Color(0xFF3EAD91),
                      size: 24,
                    ),
                  ),
                  title: Text(
                    name,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade900,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFFE8F6F3),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          iconSize: 18,
                          tooltip: "Edit",
                          onPressed: () {
                            _showEditDialog(item);
                          },
                          icon: const Icon(
                            Icons.edit_outlined,
                            color: Color(0xFF3EAD91),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFFFDE8E8),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          iconSize: 18,
                          tooltip: "Delete",
                          onPressed: () {
                            _confirmDeleteCategory(item);
                          },
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: Color(0xFFEF4444),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_category_fab',
        elevation: 3,
        backgroundColor: const Color(0xFF3EAD91),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        icon: const Icon(Icons.add_rounded, size: 24),
        label: const Text(
          "Add Category",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            letterSpacing: 0.3,
          ),
        ),
        onPressed: _showAddCategoryDialog,
      ),
    );
  }

  void _showAddCategoryDialog() {
    nameController.clear();
    selectedIcon = categoryIcons.first;
    _isSaving = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: const Text(
                "Add Category",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: "Category Name",
                          prefixIcon: const Icon(Icons.category_outlined, color: Color(0xFF3EAD91)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFF3EAD91), width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Select Icon",
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 200,
                        child: GridView.builder(
                          physics: const BouncingScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 5,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                          itemCount: categoryIcons.length,
                          itemBuilder: (context, index) {
                            final iconItem = categoryIcons[index];
                            final isSelected = selectedIcon.name == iconItem.name;

                            return GestureDetector(
                              onTap: () {
                                dialogSetState(() {
                                  selectedIcon = iconItem;
                                });
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected
                                      ? const Color(0xFF3EAD91)
                                      : const Color(0xFFE8F6F3),
                                  border: isSelected
                                      ? Border.all(color: const Color(0xFF3EAD91), width: 2)
                                      : null,
                                ),
                                child: Icon(
                                  iconItem.icon,
                                  color: isSelected ? Colors.white : const Color(0xFF3EAD91),
                                  size: 22,
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
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text("Cancel", style: TextStyle(color: Colors.grey.shade600)),
                ),
                ElevatedButton(
                  onPressed: _isSaving
                      ? null
                      : () async {
                          final trimmed = nameController.text.trim();
                          if (trimmed.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Please enter a category name"),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          dialogSetState(() {
                            _isSaving = true;
                          });

                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            await addCategory(trimmed, selectedIcon.name);
                            if (!mounted) return;
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                            _reloadCategories();
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text("Category Created Successfully"),
                                backgroundColor: Color(0xFF3EAD91),
                              ),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            messenger.showSnackBar(
                              const SnackBar(content: Text("Failed to create category")),
                            );
                          } finally {
                            if (mounted) {
                              dialogSetState(() {
                                _isSaving = false;
                              });
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3EAD91),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text("Add"),
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
    selectedIcon = categoryIcons.firstWhere(
      (e) => e.name == item['icon'],
      orElse: () => categoryIcons.first,
    );
    _isSaving = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: const Text(
                "Edit Category",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: "Category Name",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFF3EAD91), width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Select Icon",
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 200,
                        child: GridView.builder(
                          physics: const BouncingScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 5,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                          itemCount: categoryIcons.length,
                          itemBuilder: (context, index) {
                            final iconItem = categoryIcons[index];
                            final isSelected = selectedIcon.name == iconItem.name;

                            return GestureDetector(
                              onTap: () {
                                dialogSetState(() {
                                  selectedIcon = iconItem;
                                });
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected
                                      ? const Color(0xFF3EAD91)
                                      : const Color(0xFFE8F6F3),
                                  border: isSelected
                                      ? Border.all(color: const Color(0xFF3EAD91), width: 2)
                                      : null,
                                ),
                                child: Icon(
                                  iconItem.icon,
                                  color: isSelected ? Colors.white : const Color(0xFF3EAD91),
                                  size: 22,
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
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text("Cancel", style: TextStyle(color: Colors.grey.shade600)),
                ),
                ElevatedButton(
                  onPressed: _isSaving
                      ? null
                      : () async {
                          final trimmed = nameController.text.trim();
                          if (trimmed.isEmpty) {
                            return;
                          }

                          dialogSetState(() {
                            _isSaving = true;
                          });

                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            await updateCategory(
                              item['id'].toString(),
                              trimmed,
                              selectedIcon.name,
                            );

                            if (!mounted) return;
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                            _reloadCategories();

                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text("Category Updated Successfully"),
                                backgroundColor: Color(0xFF3EAD91),
                              ),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            messenger.showSnackBar(
                              const SnackBar(content: Text("Failed to update category")),
                            );
                          } finally {
                            if (mounted) {
                              dialogSetState(() {
                                _isSaving = false;
                              });
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3EAD91),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeleteCategory(Map<String, dynamic> item) {
    final categoryName = item['name']?.toString() ?? 'this category';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            "Delete Category",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(
            "Are you sure you want to delete '$categoryName'? Any expenses associated with this category will safely remain preserved under 'Uncategorized'.",
            style: TextStyle(color: Colors.grey.shade800, fontSize: 15),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text("Cancel", style: TextStyle(color: Colors.grey.shade600)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await _deleteCategory(item['id'].toString());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteCategory(String id) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await deleteCategory(id);
      if (!mounted) return;
      _reloadCategories();
      messenger.showSnackBar(
        const SnackBar(
          content: Text("Category Deleted"),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text("Failed to delete category")),
      );
    }
  }

  Future<List<dynamic>> fetchCategories() async {
    final data = await categoryRepo.getCategories();
    _allCategories = List<dynamic>.from(data);
    _filteredCategories = List<dynamic>.from(data);
    return _allCategories;
  }

  Future<void> addCategory(String name, String icon) async {
    await categoryRepo.addCategory(name, icon, basicAuth);
  }

  Future<void> updateCategory(String id, String name, String icon) async {
    await categoryRepo.updateCategory(id, name, icon, basicAuth);
  }

  Future<void> deleteCategory(String id) async {
    await categoryRepo.deleteCategory(id, basicAuth);
  }

  void _searchCategories(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      setState(() {
        _filteredCategories = _allCategories;
      });
    } else {
      final results = await categoryRepo.searchCategories(trimmedQuery);
      if (!mounted) return;
      setState(() {
        _filteredCategories = results;
      });
    }
  }

  IconData getIconFromName(String? item) {
    for (final categoryIcon in categoryIcons) {
      if (categoryIcon.name == item) {
        return categoryIcon.icon;
      }
    }
    return Icons.category_outlined;
  }
}
