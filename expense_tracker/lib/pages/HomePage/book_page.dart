import 'dart:async';
import 'dart:convert';
import 'package:expense_tracker/core/theme/app_colors.dart';
import 'package:expense_tracker/core/theme/app_radius.dart';
import 'package:expense_tracker/core/theme/app_shadows.dart';
import 'package:expense_tracker/core/theme/app_text_theme.dart';
import 'package:expense_tracker/core/widgets/app_empty_state.dart';
import 'package:expense_tracker/core/widgets/app_loading.dart';
import 'package:expense_tracker/pages/HomePage/Expenses/category_page.dart';
import 'package:expense_tracker/pages/HomePage/Expenses/inside_book_page.dart';
import 'package:expense_tracker/pages/archived_page.dart';
import 'package:expense_tracker/repositories/repository.dart';
import 'package:expense_tracker/services/connectivity_service.dart';
import 'package:expense_tracker/services/currency_service.dart';
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
            shape: RoundedRectangleBorder(borderRadius: AppRadius.dialog),
            title: const Text(
              "Add Book",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: bookNameController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: "Book Name",
                    hintText: "e.g. Personal Expenses, Travel",
                    errorText: nameError,
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.medium,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: AppRadius.medium,
                      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: bookSubtitleController,
                  decoration: InputDecoration(
                    labelText: "Book Subtitle",
                    hintText: "Optional short note or tag",
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.medium,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: AppRadius.medium,
                      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text("Cancel", style: TextStyle(color: AppColors.textSecondary)),
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
                  await addBook(trimmedName, bookSubtitleController.text.trim());

                  if (!mounted) return;
                  await _reloadBooks();

                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text("Book Added Successfully"),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textWhite,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.medium,
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

  void _showEditBookDialog(String id, String currentName, String currentSubtitle) {
    bookNameController.text = currentName;
    bookSubtitleController.text = currentSubtitle;
    String? nameError;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, dialogSetState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: AppRadius.dialog),
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
                    labelText: "Book Name",
                    errorText: nameError,
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.medium,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: AppRadius.medium,
                      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: bookSubtitleController,
                  decoration: InputDecoration(
                    labelText: "Book Subtitle",
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.medium,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: AppRadius.medium,
                      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text("Cancel", style: TextStyle(color: AppColors.textSecondary)),
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
                      backgroundColor: AppColors.primary,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textWhite,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.medium,
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
        shape: RoundedRectangleBorder(borderRadius: AppRadius.dialog),
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
              style: AppTextTheme.bodyLarge,
            ),
            if (bookSubtitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                "Subtitle: $bookSubtitle",
                style: AppTextTheme.bodyMedium,
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
            child: const Text("Edit", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              showDialog(
                context: context,
                builder: (confirmContext) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.dialog),
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
                      child: const Text("Cancel", style: TextStyle(color: AppColors.textSecondary)),
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
                            backgroundColor: AppColors.primary,
                          ),
                        );
                      },
                      child: const Text(
                        "Archive",
                        style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.bold),
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
                            backgroundColor: AppColors.expense,
                          ),
                        );
                      },
                      child: const Text(
                        "Delete",
                        style: TextStyle(color: AppColors.expense, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              );
            },
            child: const Text("Delete / Archive", style: TextStyle(color: AppColors.expense, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
            },
            child: const Text("Close", style: TextStyle(color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        surfaceTintColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: AppColors.primaryTint,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_rounded, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              "Tracklet SaveBuddy",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 6),
            decoration: const BoxDecoration(
              color: AppColors.primaryTint,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(
                Icons.category_outlined,
                color: AppColors.primary,
                size: 20,
              ),
              tooltip: "Categories",
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
          Container(
            margin: const EdgeInsets.only(right: 6),
            decoration: const BoxDecoration(
              color: AppColors.primaryTint,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(
                Icons.archive_outlined,
                color: AppColors.primary,
                size: 20,
              ),
              tooltip: "Archived",
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
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: const BoxDecoration(
              color: AppColors.primaryTint,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              iconSize: 20,
              tooltip: "Notifications",
              onPressed: () {},
              icon: const Icon(Icons.notifications_none_rounded, color: AppColors.primary),
            ),
          ),
        ],
      ),
      body: buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_book_fab',
        tooltip: 'Add Book',
        backgroundColor: AppColors.primary,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.pill,
        ),
        onPressed: _showAddBookDialog,
        icon: const Icon(Icons.add_rounded, color: AppColors.textWhite, size: 24),
        label: const Text(
          "Add Book",
          style: TextStyle(
            color: AppColors.textWhite,
            fontSize: 15,
            fontWeight: FontWeight.bold,
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

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title Header Section
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "My Books",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.textWhite : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                "Manage your financial spaces",
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.textMuted : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Search Section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: AppRadius.large,
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
              boxShadow: AppShadows.cardShadowList,
            ),
            child: TextField(
              controller: searchController,
              onChanged: filterBooks,
              style: TextStyle(fontSize: 15, color: isDark ? AppColors.textWhite : AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: "Search books...",
                hintStyle: TextStyle(color: isDark ? AppColors.textMuted : AppColors.textMuted, fontSize: 14),
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary, size: 20),
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        color: AppColors.textMuted,
                        onPressed: () {
                          searchController.clear();
                          filterBooks('');
                        },
                      )
                    : null,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Books List Section
        Expanded(
          child: filteredBooks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.search_off_rounded,
                        size: 56,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "No matching books found",
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textSecondary,
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
        bgColor = AppColors.primaryTint;
        textColor = AppColors.primary;
        icon = Icons.cloud_done_rounded;
        text = "Synced";
        break;
      case 2:
        bgColor = AppColors.expenseTint;
        textColor = AppColors.expense;
        icon = Icons.cloud_off_rounded;
        text = "Sync Failed";
        break;
      case 0:
      default:
        bgColor = AppColors.warningTint;
        textColor = AppColors.warning;
        icon = Icons.cloud_upload_outlined;
        text = "Pending";
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: textColor, size: 11),
          const SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(
              color: textColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tagSubtitle = widget.subtitle.isEmpty ? "DEFAULT" : widget.subtitle.toUpperCase();

    return AnimatedScale(
      scale: isPressed ? 0.98 : 1.0,
      duration: const Duration(milliseconds: 100),
      child: Material(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: AppRadius.xLarge,
        child: InkWell(
          borderRadius: AppRadius.xLarge,
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
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: AppRadius.xLarge,
                border: Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
                boxShadow: AppShadows.cardShadowList,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.catIcon,
                      color: AppColors.textWhite,
                      size: 22,
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
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.textWhite : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              tagSubtitle,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.textMuted : AppColors.textSecondary,
                                letterSpacing: 0.5,
                              ),
                            ),
                            if (widget.subtitle.isNotEmpty) ...[
                              const SizedBox(width: 4),
                              Text(
                                "• ${widget.subtitle}",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? AppColors.textMuted : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        _buildSyncBadge(widget.syncedStatus),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "Balance",
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.textMuted : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      FutureBuilder<double>(
                        future: ExpenseRepository().getBookBalance(widget.item['id'].toString()),
                        builder: (context, snapshot) {
                          final double rawBalance = snapshot.data ?? (widget.item['amount'] as num?)?.toDouble() ?? 0.0;
                          return ValueListenableBuilder<String>(
                            valueListenable: CurrencyService.currencyNotifier,
                            builder: (context, _, child) {
                              return Text(
                                CurrencyService.format(rawBalance),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? AppColors.textWhite : AppColors.textPrimary,
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.more_vert_rounded,
                      color: isDark ? AppColors.textMuted : AppColors.textSecondary,
                      size: 20,
                    ),
                    onPressed: widget.onLongPress,
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
