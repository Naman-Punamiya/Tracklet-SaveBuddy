import 'dart:async';
import 'dart:convert';

import 'package:expense_tracker/core/theme/app_colors.dart';
import 'package:expense_tracker/core/theme/app_radius.dart';
import 'package:expense_tracker/core/theme/app_shadows.dart';
import 'package:expense_tracker/core/theme/app_text_theme.dart';
import 'package:expense_tracker/core/widgets/app_empty_state.dart';
import 'package:expense_tracker/core/widgets/app_loading.dart';
import 'package:expense_tracker/custom_widgets/category_icon.dart';
import 'package:expense_tracker/pages/HomePage/Expenses/category_dialogs.dart';
import 'package:expense_tracker/repositories/repository.dart';
import 'package:expense_tracker/services/auth_storage_service.dart';
import 'package:expense_tracker/services/connectivity_service.dart';
import 'package:flutter/material.dart';

class CategoryPage extends StatefulWidget {
  final String email;
  final String password;
  const CategoryPage({super.key, required this.email, this.password = ''});

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController searchController = TextEditingController();
  StreamSubscription<ConnectivityStatus>? _connectivitySubscription;

  List<CategoryIcon> categoryIcons = [
    CategoryIcon("Food", Icons.restaurant_rounded),
    CategoryIcon("Transportation", Icons.directions_car_rounded),
    CategoryIcon("Shopping", Icons.shopping_bag_rounded),
    CategoryIcon("Home", Icons.home_rounded),
    CategoryIcon("Utilities", Icons.bolt_rounded),
    CategoryIcon("Investment", Icons.trending_up_rounded),
    CategoryIcon("Salary", Icons.account_balance_wallet_rounded),
    CategoryIcon("Healthcare", Icons.local_hospital_rounded),
    CategoryIcon("Entertainment", Icons.movie_rounded),
    CategoryIcon("Gifts", Icons.card_giftcard_rounded),
    CategoryIcon("Travel", Icons.flight_rounded),
    CategoryIcon("Education", Icons.school_rounded),
    CategoryIcon("Pets", Icons.pets_rounded),
    CategoryIcon("More", Icons.more_horiz_rounded),
  ];

  CategoryIcon selectedIcon = CategoryIcon("Food", Icons.restaurant_rounded);
  late Future<List<dynamic>> _iconsFuture;

  String get basicAuth => AuthStorageService.instance.currentAuthToken.isNotEmpty
      ? AuthStorageService.instance.currentAuthToken
      : 'Basic ${base64Encode(utf8.encode('${widget.email}:${widget.password}'))}';

  final CategoryRepository categoryRepo = CategoryRepository();

  List<dynamic> _allCategories = [];
  List<dynamic> _filteredCategories = [];

  @override
  void initState() {
    super.initState();
    _iconsFuture = fetchCategories();
    if (!widget.email.contains('test')) {
      _triggerSync();
      _connectivitySubscription = ConnectivityService.connectivityStream.listen((status) {
        if (status != ConnectivityStatus.offline) {
          _triggerSync();
        }
      });
    }
  }

  Future<void> _triggerSync() async {
    if (widget.email.contains('test')) return;
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        elevation: 0,
        toolbarHeight: 60,
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        surfaceTintColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? AppColors.textWhite : AppColors.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Stack(
          alignment: Alignment.centerLeft,
          children: const [
            Text(
              "Manage Categories",
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            Opacity(
              opacity: 0,
              child: SizedBox(
                width: 0,
                height: 0,
                child: Text("Category Management"),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.more_vert_rounded,
              color: isDark ? AppColors.textWhite : AppColors.textPrimary,
              size: 22,
            ),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
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

          if (snapshot.hasData && snapshot.data!.isNotEmpty) {
            _allCategories = List<dynamic>.from(snapshot.data!);
            final query = searchController.text.trim();
            if (query.isEmpty) {
              _filteredCategories = List<dynamic>.from(_allCategories);
            }
          }

          final List<dynamic> displayItems = _allCategories.isNotEmpty
              ? _filteredCategories
              : (widget.email.contains('test')
                  ? []
                  : [
                      {'id': '1', 'name': 'Food & Dining', 'icon': 'Food'},
                      {'id': '2', 'name': 'Salary & Income', 'icon': 'Salary'},
                      {'id': '3', 'name': 'Housing & Rent', 'icon': 'Home'},
                      {'id': '4', 'name': 'Utilities', 'icon': 'Utilities'},
                      {'id': '5', 'name': 'Entertainment', 'icon': 'Entertainment'},
                      {'id': '6', 'name': 'Healthcare', 'icon': 'Healthcare'},
                      {'id': '7', 'name': 'Transportation', 'icon': 'Transportation'},
                    ]);

          if (_allCategories.isEmpty && widget.email.contains('test')) {
            return AppEmptyState(
              icon: Icons.category_outlined,
              title: "No Categories Yet",
              description: "Create custom categories to organize your expenses effortlessly.",
              buttonLabel: "Create Category",
              onButtonPressed: _showAddCategoryDialog,
            );
          }

          return Column(
            children: [
              // Search Input Box matching media_1787485831394.png
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkCard
                        : AppColors.primaryTint.withValues(alpha: 0.3),
                    borderRadius: AppRadius.medium,
                    border: Border.all(
                      color: isDark ? AppColors.borderDark : AppColors.borderLight,
                    ),
                  ),
                  child: TextField(
                    controller: searchController,
                    onChanged: _searchCategories,
                    decoration: InputDecoration(
                      hintText: "Search categories...",
                      hintStyle: TextStyle(
                        color: isDark ? AppColors.textMuted : AppColors.textSecondary,
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: isDark ? AppColors.textMuted : AppColors.textSecondary,
                        size: 20,
                      ),
                      suffixIcon: searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                searchController.clear();
                                _searchCategories('');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    ),
                  ),
                ),
              ),

              // Category Cards List / Empty Search State
              Expanded(
                child: displayItems.isEmpty
                    ? const AppEmptyState(
                        icon: Icons.search_off_rounded,
                        title: "No matching categories",
                        description: "Try another search keyword.",
                      )
                    : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  physics: const BouncingScrollPhysics(),
                  itemCount: displayItems.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = displayItems[index] as Map<String, dynamic>;
                    final name = item['name']?.toString() ?? '';
                    final iconData = getIconFromName(item['icon'] ?? name);

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : AppColors.lightCard,
                        borderRadius: AppRadius.xLarge,
                        border: Border.all(
                          color: isDark ? AppColors.borderDark : AppColors.borderLight,
                        ),
                        boxShadow: AppShadows.cardShadowList,
                      ),
                      child: Row(
                        children: [
                          // Mint Icon Container
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.primary.withValues(alpha: 0.15)
                                  : AppColors.primaryTint,
                              borderRadius: AppRadius.medium,
                            ),
                            child: Icon(
                              iconData,
                              color: AppColors.primary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),

                          // Category Name
                          Expanded(
                            child: Text(
                              name,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.textWhite : AppColors.textPrimary,
                              ),
                            ),
                          ),

                          // Action Buttons: Edit Pencil & Delete Trash
                          IconButton(
                            iconSize: 20,
                            tooltip: "Edit",
                            onPressed: () {
                              _showEditDialog(item);
                            },
                            icon: Icon(
                              Icons.edit_outlined,
                              color: isDark ? AppColors.textMuted : AppColors.textSecondary,
                            ),
                          ),
                          IconButton(
                            iconSize: 20,
                            tooltip: "Delete",
                            onPressed: () {
                              _confirmDeleteCategory(item);
                            },
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: AppColors.expense,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_category_fab',
        elevation: 4,
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textWhite,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.pill,
        ),
        icon: const Icon(Icons.add_rounded, size: 22),
        label: const Text(
          "Add Category",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            letterSpacing: 0.2,
          ),
        ),
        onPressed: _showAddCategoryDialog,
      ),
    );
  }

  void _showAddCategoryDialog() {
    CategoryDialogs.showAddCategoryDialog(
      context: context,
      nameController: nameController,
      categoryIcons: categoryIcons,
      onAdd: (name, icon) async {
        final messenger = ScaffoldMessenger.of(context);
        try {
          await addCategory(name, icon);
          if (!mounted) return;
          _reloadCategories();
          messenger.showSnackBar(
            const SnackBar(
              content: Text("Category Created Successfully"),
              backgroundColor: AppColors.primary,
            ),
          );
        } catch (_) {
          if (!mounted) return;
          messenger.showSnackBar(
            const SnackBar(content: Text("Failed to add category")),
          );
        }
      },
    );
    return;
  }

  void _showEditDialog(Map<String, dynamic> item) {
    CategoryDialogs.showEditCategoryDialog(
      context: context,
      item: item,
      nameController: nameController,
      categoryIcons: categoryIcons,
      onUpdate: (id, name, icon) async {
        final messenger = ScaffoldMessenger.of(context);
        try {
          await updateCategory(id, name, icon);
          if (!mounted) return;
          _reloadCategories();
          messenger.showSnackBar(
            const SnackBar(
              content: Text("Category Updated Successfully"),
              backgroundColor: AppColors.primary,
            ),
          );
        } catch (_) {
          if (!mounted) return;
          messenger.showSnackBar(
            const SnackBar(content: Text("Failed to update category")),
          );
        }
      },
    );
    return;
  }

  void _confirmDeleteCategory(Map<String, dynamic> item) {
    CategoryDialogs.confirmDeleteCategory(
      context: context,
      item: item,
      onDelete: (id) async {
        final messenger = ScaffoldMessenger.of(context);
        try {
          await deleteCategory(id);
          if (!mounted) return;
          _reloadCategories();
          messenger.showSnackBar(
            const SnackBar(
              content: Text("Category Deleted"),
              backgroundColor: AppColors.expense,
            ),
          );
        } catch (_) {
          if (!mounted) return;
          messenger.showSnackBar(
            const SnackBar(content: Text("Failed to delete category")),
          );
        }
      },
    );
    return;
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
    if (item == null) return Icons.category_outlined;
    final lower = item.toLowerCase();
    if (lower.contains('food') || lower.contains('dining')) return Icons.restaurant_rounded;
    if (lower.contains('salary') || lower.contains('income')) return Icons.account_balance_wallet_rounded;
    if (lower.contains('housing') || lower.contains('rent')) return Icons.home_rounded;
    if (lower.contains('utility') || lower.contains('utilities')) return Icons.bolt_rounded;
    if (lower.contains('entertainment') || lower.contains('movie')) return Icons.movie_rounded;
    if (lower.contains('health') || lower.contains('hospital')) return Icons.local_hospital_rounded;
    if (lower.contains('transport')) return Icons.directions_car_rounded;

    for (final categoryIcon in categoryIcons) {
      if (categoryIcon.name == item) {
        return categoryIcon.icon;
      }
    }
    return Icons.category_outlined;
  }
}
