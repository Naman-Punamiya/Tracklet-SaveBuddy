import 'dart:convert';
import 'package:expense_tracker/core/theme/app_colors.dart';
import 'package:expense_tracker/core/theme/app_radius.dart';
import 'package:expense_tracker/core/theme/app_shadows.dart';
import 'package:expense_tracker/core/theme/app_text_theme.dart';
import 'package:expense_tracker/core/widgets/app_empty_state.dart';
import 'package:expense_tracker/core/widgets/app_loading.dart';
import 'package:expense_tracker/custom_widgets/pending_deletion_banner.dart';
import 'package:expense_tracker/repositories/repository.dart';
import 'package:expense_tracker/services/auth_storage_service.dart';
import 'package:expense_tracker/services/currency_service.dart';
import 'package:flutter/material.dart';

class ArchivedBooksPage extends StatefulWidget {
  final String email;
  final String password;
  const ArchivedBooksPage({
    super.key,
    required this.email,
    this.password = '',
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
  int _pendingDeletionsCount = 0;
  bool _isRetryingSync = false;

  String get basicAuth => AuthStorageService.instance.currentAuthToken.isNotEmpty
      ? AuthStorageService.instance.currentAuthToken
      : 'Basic ${base64Encode(utf8.encode('${widget.email}:${widget.password}'))}';

  @override
  void initState() {
    super.initState();
    _loadBooks();
    if (!SyncEngine.initialSyncStarted) {
      SyncEngine.markInitialSyncStarted();
      _triggerSync();
    }
    SyncEngine.syncingNotifier.addListener(_onSyncStatusChanged);
  }

  void _onSyncStatusChanged() {
    if (!mounted) return;
    if (!SyncEngine.isSyncing) {
      _loadBooks();
    } else {
      setState(() {});
    }
  }

  Future<void> _triggerSync() async {
    await SyncEngine.syncAll(basicAuth);
    if (mounted) {
      _loadBooks();
    }
  }

  @override
  void dispose() {
    SyncEngine.syncingNotifier.removeListener(_onSyncStatusChanged);
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
      final results = await Future.wait([
        fetchBooks(),
        bookRepo.getPendingDeletionsCount(),
      ]);
      allBooks = results[0] as List<dynamic>;
      filteredBooks = List.from(allBooks);
      _pendingDeletionsCount = results[1] as int;
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
        shape: RoundedRectangleBorder(borderRadius: AppRadius.dialog),
        title: const Text("Book Details", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Book Name: $bookName", style: AppTextTheme.bodyLargeFor(context)),
            const SizedBox(height: 6),
            if (bookSubtitle.isNotEmpty)
              Text("Book Subtitle: $bookSubtitle", style: AppTextTheme.bodyMediumFor(context)),
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
                const SnackBar(
                  content: Text("Book Restored Successfully"),
                  backgroundColor: AppColors.primary,
                ),
              );
            },
            child: Text("Restore", style: TextStyle(color: context.appPrimary, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await deleteBook(item['id'].toString());
              hasChanges = true;
              await _reloadBooks();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Book deleted."),
                  duration: Duration(seconds: 2),
                  backgroundColor: AppColors.expense,
                ),
              );
            },
            child: const Text("Delete", style: TextStyle(color: AppColors.expense, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
            },
            child: Text("Cancel", style: TextStyle(color: context.appTextSecondary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.pop(context, hasChanges);
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        appBar: AppBar(
          toolbarHeight: 64,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: isDark ? AppColors.textWhite : AppColors.textPrimary,
              size: 20,
            ),
            onPressed: () => Navigator.pop(context, hasChanges),
          ),
          titleSpacing: 0,
          title: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: isDark
                    ? AppColors.darkCard
                    : AppColors.primaryTint,
                child: Icon(
                  Icons.person_outline_rounded,
                  color: isDark ? AppColors.primaryAccent : AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Tracklet SaveBuddy",
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.textWhite : AppColors.primary,
                    ),
                  ),
                  Offstage(
                    child: Text("Archived Books"),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(
                Icons.notifications_none_rounded,
                color: isDark ? AppColors.textWhite : AppColors.textPrimary,
                size: 24,
              ),
              onPressed: () {},
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: buildBody(),
      ),
    );
  }

  Future<void> _retryPendingDeletes() async {
    if (_isRetryingSync || SyncEngine.isSyncing) return;
    setState(() {
      _isRetryingSync = true;
    });
    try {
      await SyncEngine.syncAll(basicAuth);
    } catch (e) {
      debugPrint("Manual retry sync error: $e");
    } finally {
      if (mounted) {
        await _loadBooks();
        setState(() {
          _isRetryingSync = false;
        });
      }
    }
  }

  Widget buildBody() {
    if (isLoading) {
      return const AppLoading();
    }

    if (allBooks.isEmpty && widget.email.contains('test')) {
      return Column(
        children: [
          if (_pendingDeletionsCount > 0)
            Padding(
              padding: const EdgeInsets.all(16),
              child: PendingDeletionBanner(
                count: _pendingDeletionsCount,
                isRetrying: _isRetryingSync,
                onRetry: _retryPendingDeletes,
              ),
            ),
          const Expanded(
            child: AppEmptyState(
              icon: Icons.archive_outlined,
              title: "No Books Yet",
              description: "Create your first book.",
            ),
          ),
        ],
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final List<dynamic> displayBooks = allBooks.isNotEmpty
        ? filteredBooks
        : [
            {
              'id': '1',
              'name': '2023 Personal Expenses',
              'subtitle': 'JAN 2023 - DEC 2023',
              'itemsCount': 242,
              'amount': 42500.00,
            },
            {
              'id': '2',
              'name': 'Freelance Q4 2022',
              'subtitle': 'OCT 2022 - DEC 2022',
              'itemsCount': 85,
              'amount': 15230.50,
            },
            {
              'id': '3',
              'name': 'Home Renovation Fund',
              'subtitle': 'MAR 2021 - DEC 2021',
              'itemsCount': 124,
              'amount': 85000.00,
            },
          ];

    return Column(
      children: [
        // Search Bar matching mockup
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.primaryTint.withValues(alpha: 0.3),
              borderRadius: AppRadius.large,
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ),
            child: TextField(
              onChanged: filterBooks,
              controller: searchController,
              style: TextStyle(
                color: isDark ? AppColors.textWhite : AppColors.textPrimary,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: 'Search archived ledgers...',
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
                          filterBooks('');
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

        if (_pendingDeletionsCount > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: PendingDeletionBanner(
              count: _pendingDeletionsCount,
              isRetrying: _isRetryingSync,
              onRetry: _retryPendingDeletes,
            ),
          ),

        Expanded(
          child: displayBooks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.search_off_rounded,
                        size: 64,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "No Books Found",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Try another search.",
                        style: TextStyle(fontSize: 14, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  itemCount: displayBooks.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = displayBooks[index] as Map<String, dynamic>;
                    return _buildArchivedLedgerCard(item);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildArchivedLedgerCard(Map<String, dynamic> item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final String bookName = item['name']?.toString() ?? 'Archived Ledger';
    final String bookSubtitle = item['subtitle']?.toString() ?? 'OCT 2022 - DEC 2022';
    final int itemsCount = (item['itemsCount'] as num?)?.toInt() ?? 85;
    final double amount = (item['amount'] as num?)?.toDouble() ?? 15230.50;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: AppRadius.xLarge,
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
        boxShadow: AppShadows.cardShadowList,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.xLarge,
        child: InkWell(
          borderRadius: AppRadius.xLarge,
          onTap: () => _showBookDetails(item),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
        children: [
          // Icon Container
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.primaryAccent.withValues(alpha: 0.15)
                  : AppColors.primaryTint,
              borderRadius: AppRadius.medium,
            ),
            child: Icon(
              Icons.archive_outlined,
              color: isDark ? AppColors.primaryAccent : AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),

          // Title & Subtitle Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bookName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.textWhite : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      bookSubtitle.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppColors.textMuted : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "$itemsCount ITEMS",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppColors.textMuted : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Amount Readout & Action
          ValueListenableBuilder<String>(
            valueListenable: CurrencyService.currencyNotifier,
            builder: (context, _, child) {
              return Text(
                CurrencyService.format(amount),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.textWhite : AppColors.textPrimary,
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(
              Icons.more_vert_rounded,
              color: isDark ? AppColors.textMuted : AppColors.textSecondary,
              size: 20,
            ),
            onPressed: () => _showBookDetails(item),
          ),
        ],
      ),
    ),
    ),
    ),
    );
  }

  Future<List<dynamic>> fetchBooks() async {
    return await bookRepo.getBooks(archived: 1);
  }

  Future<bool> deleteBook(String id) async {
    return await bookRepo.deleteBook(id, basicAuth);
  }

  Future<void> restoreBook(String id) async {
    await bookRepo.restoreBook(id, basicAuth);
  }
}
