import 'dart:async';
import 'dart:convert';
import 'package:expense_tracker/core/theme/app_colors.dart';
import 'package:expense_tracker/core/widgets/app_empty_state.dart';
import 'package:expense_tracker/core/widgets/app_loading.dart';
import 'package:expense_tracker/pages/HomePage/Expenses/category_page.dart';
import 'package:expense_tracker/pages/HomePage/Expenses/inside_book_page.dart';
import 'package:expense_tracker/pages/HomePage/book_dialogs.dart';
import 'package:expense_tracker/pages/archived_page.dart';
import 'package:expense_tracker/repositories/repository.dart';
import 'package:expense_tracker/services/auth_storage_service.dart';
import 'package:expense_tracker/services/connectivity_service.dart';
import 'package:expense_tracker/services/currency_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const List<Color> _pastelColors = [
  Color(0xFFD3F6E6), // Mint Green (Personal)
  Color(0xFFDFEAFD), // Soft Periwinkle Blue (Household)
  Color(0xFFFEF0C7), // Warm Pastel Yellow (Trip fund)
  Color(0xFFFCE7F3), // Soft Blush Pink
  Color(0xFFEDE9FE), // Soft Lavender
  Color(0xFFDCFCE7), // Pastel Sage
  Color(0xFFFFEDD5), // Soft Peach
];

String _getMonogram(String name) {
  final clean = name.trim();
  if (clean.isEmpty) return 'Bk';
  if (clean.length == 1) return clean.toUpperCase();
  return clean[0].toUpperCase() + clean[1].toLowerCase();
}

String _getGreeting() {
  final hour = DateTime.now().hour;
  if (hour >= 5 && hour < 12) {
    return 'Good morning';
  } else if (hour >= 12 && hour < 17) {
    return 'Good afternoon';
  } else if (hour >= 17 && hour < 22) {
    return 'Good evening';
  } else {
    return 'Good night';
  }
}

class BookPage extends StatefulWidget {
  final String email;
  final String password;
  const BookPage({super.key, required this.email, this.password = ''});

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
  double _totalBalance = 0.0;

  String get basicAuth => AuthStorageService.instance.currentAuthToken.isNotEmpty
      ? AuthStorageService.instance.currentAuthToken
      : 'Basic ${base64Encode(utf8.encode('${widget.email}:${widget.password}'))}';

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
    if (widget.email.contains('test')) return;
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
      double total = 0.0;
      for (var book in allBooks) {
        final bal = await ExpenseRepository().getBookBalance(book['id'].toString());
        total += bal;
      }
      if (mounted) {
        setState(() {
          _totalBalance = total;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _showAddBookDialog() {
    BookDialogs.showAddBookDialog(
      context: context,
      nameController: bookNameController,
      subtitleController: bookSubtitleController,
      onAdd: (name, subtitle) async {
        final messenger = ScaffoldMessenger.of(context);
        await addBook(name, subtitle);
        if (!mounted) return;
        await _reloadBooks();
        messenger.showSnackBar(
          const SnackBar(
            content: Text("Book Added Successfully"),
            backgroundColor: Color(0xFF0A7A3E),
          ),
        );
      },
    );
    return;
  }

  void _showEditBookDialog(String id, String currentName, String currentSubtitle) {
    BookDialogs.showEditBookDialog(
      context: context,
      id: id,
      currentName: currentName,
      currentSubtitle: currentSubtitle,
      nameController: bookNameController,
      subtitleController: bookSubtitleController,
      onUpdate: (id, name, subtitle) async {
        final messenger = ScaffoldMessenger.of(context);
        await updateBook(id, name, subtitle);
        if (!mounted) return;
        await _reloadBooks();
        messenger.showSnackBar(
          const SnackBar(
            content: Text("Book Updated Successfully"),
            backgroundColor: Color(0xFF0A7A3E),
          ),
        );
      },
    );
    return;
  }

  void _showBookDetails(Map<String, dynamic> item) {
    final String bookName = item['name']?.toString() ?? '';
    final String bookSubtitle = item['subtitle']?.toString() ?? '';
    BookDialogs.showBookDetails(
      context: context,
      item: item,
      onEdit: () => _showEditBookDialog(item['id'].toString(), bookName, bookSubtitle),
      onArchive: () async {
        final messenger = ScaffoldMessenger.of(context);
        await archiveBook(item['id'].toString());
        if (!mounted) return;
        await _reloadBooks();
        messenger.showSnackBar(
          const SnackBar(
            content: Text("Book Archived Successfully"),
            backgroundColor: Color(0xFF0A7A3E),
          ),
        );
      },
      onDelete: () async {
        final messenger = ScaffoldMessenger.of(context);
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
    );
    return;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFFAF8F3);

    return Scaffold(
      backgroundColor: backgroundColor,
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF065F46),
        foregroundColor: Colors.white,
        elevation: 4,
        shape: const CircleBorder(),
        tooltip: 'Add Book',
        onPressed: _showAddBookDialog,
        child: const Icon(Icons.add_rounded, size: 30),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(isDark),
              if (allBooks.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildTotalBalanceCard(isDark),
              ],
              const SizedBox(height: 14),
              _buildSearchBar(isDark),
              const SizedBox(height: 14),
              Expanded(
                child: buildBody(isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTotalBalanceCard(bool isDark) {
    final int totalBooks = allBooks.length;
    final int syncedBooks = allBooks.where((b) {
      final s = b['synced'];
      return s == 1 || s == true || s == null;
    }).length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Total balance",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.textMuted : const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 4),
              ValueListenableBuilder<String>(
                valueListenable: CurrencyService.currencyNotifier,
                builder: (context, _, child) {
                  return Text(
                    CurrencyService.format(_totalBalance),
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                      letterSpacing: -0.5,
                    ),
                  );
                },
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF064E3B).withValues(alpha: 0.5)
                  : const Color(0xFFD4F4E4),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              totalBooks > 0 ? "$syncedBooks of $totalBooks synced" : "Synced",
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF065F46),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getGreeting(),
                style: GoogleFonts.caveat(
                  fontSize: 44,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2,
                  color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                "Here are your books",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: isDark ? AppColors.textMuted : const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeaderCircleButton(
              icon: Icons.category_outlined,
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
              isDark: isDark,
            ),
            const SizedBox(width: 8),
            _buildHeaderCircleButton(
              icon: Icons.archive_outlined,
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
              isDark: isDark,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeaderCircleButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    required bool isDark,
  }) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
          width: 1,
        ),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 18, color: const Color(0xFF065F46)),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEDEDEA),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: TextField(
        controller: searchController,
        onChanged: filterBooks,
        style: TextStyle(
          fontSize: 14,
          color: isDark ? Colors.white : const Color(0xFF1A1A1A),
        ),
        decoration: InputDecoration(
          hintText: "Search books...",
          hintStyle: TextStyle(
            color: isDark ? AppColors.textMuted : const Color(0xFF6B7280),
            fontSize: 14,
          ),
          icon: const Icon(
            Icons.search_rounded,
            color: Color(0xFF6B7280),
            size: 20,
          ),
          suffixIcon: searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  color: const Color(0xFF6B7280),
                  onPressed: () {
                    searchController.clear();
                    filterBooks('');
                  },
                )
              : null,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  Widget buildBody(bool isDark) {
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

    if (filteredBooks.isEmpty && searchController.text.trim().isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 56,
              color: Color(0xFF9CA3AF),
            ),
            const SizedBox(height: 12),
            Text(
              "No matching books found",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.textMuted : const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      );
    }

    final bool isSearching = searchController.text.trim().isNotEmpty;
    final int itemCount = filteredBooks.length + (isSearching ? 0 : 1);

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 90),
      itemCount: itemCount,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (!isSearching && index == filteredBooks.length) {
          return _buildNewBookCard(isDark);
        }

        final item = filteredBooks[index] as Map<String, dynamic>;
        final String bookName = item['name']?.toString() ?? 'Unnamed';
        final String subtitle = item['subtitle']?.toString() ?? '';
        final Color cardColor = _pastelColors[index % _pastelColors.length];

        final syncedVal = item['synced'];
        final int syncedStatus = syncedVal is int
            ? syncedVal
            : (syncedVal == true || syncedVal == null ? 1 : 0);

        return _BookCardItem(
          key: ValueKey(item['id']),
          item: item,
          bookName: bookName,
          subtitle: subtitle,
          cardColor: cardColor,
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
    );
  }

  Widget _buildNewBookCard(bool isDark) {
    return InkWell(
      key: const ValueKey('new_book_card'),
      onTap: _showAddBookDialog,
      borderRadius: BorderRadius.circular(24),
      child: CustomPaint(
        painter: DashedRoundedBorderPainter(
          color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
          radius: 24,
          strokeWidth: 1.6,
          dashLength: 6,
          dashGap: 4,
        ),
        child: Container(
          height: 76,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: isDark ? const Color(0x05FFFFFF) : Colors.transparent,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add_rounded,
                  size: 26,
                  color: Color(0xFF065F46),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "New book",
                style: GoogleFonts.caveat(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
        ),
      ),
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
  final Color cardColor;
  final int syncedStatus;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _BookCardItem({
    super.key,
    required this.item,
    required this.bookName,
    required this.subtitle,
    required this.cardColor,
    required this.syncedStatus,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  State<_BookCardItem> createState() => _BookCardItemState();
}

class _BookCardItemState extends State<_BookCardItem> {
  bool isPressed = false;

  @override
  Widget build(BuildContext context) {
    const textColor = Color(0xFF111827);

    return AnimatedScale(
      scale: isPressed ? 0.98 : 1.0,
      duration: const Duration(milliseconds: 100),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTapDown: (_) => setState(() => isPressed = true),
          onTapUp: (_) => setState(() => isPressed = false),
          onTapCancel: () => setState(() => isPressed = false),
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              color: widget.cardColor,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x06000000),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // White rounded square avatar with monogram
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x06000000),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _getMonogram(widget.bookName),
                    style: GoogleFonts.caveat(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1A1A1A),
                      height: 1.0,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Book Title and Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.bookName,
                        style: GoogleFonts.caveat(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                          height: 1.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (widget.subtitle.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2.0),
                          child: Text(
                            widget.subtitle,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF4B5563),
                              fontWeight: FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
                // Book Balance Amount & Sync indicator
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FutureBuilder<double>(
                      future: ExpenseRepository()
                          .getBookBalance(widget.item['id'].toString()),
                      builder: (context, snapshot) {
                        final double rawBalance = snapshot.data ??
                            (widget.item['amount'] as num?)?.toDouble() ??
                            0.0;
                        return ValueListenableBuilder<String>(
                          valueListenable: CurrencyService.currencyNotifier,
                          builder: (context, _, child) {
                            return Text(
                              CurrencyService.format(rawBalance),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                                letterSpacing: -0.3,
                              ),
                            );
                          },
                        );
                      },
                    ),
                    if (widget.syncedStatus != 1) ...[
                      const SizedBox(height: 4),
                      Icon(
                        widget.syncedStatus == 2
                            ? Icons.cloud_off_rounded
                            : Icons.cloud_upload_outlined,
                        size: 14,
                        color: widget.syncedStatus == 2
                            ? AppColors.expense
                            : AppColors.warning,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DashedRoundedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double radius;
  final double dashLength;
  final double dashGap;

  DashedRoundedBorderPainter({
    required this.color,
    this.strokeWidth = 1.8,
    this.radius = 24.0,
    this.dashLength = 6.0,
    this.dashGap = 4.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        strokeWidth / 2,
        strokeWidth / 2,
        size.width - strokeWidth,
        size.height - strokeWidth,
      ),
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);
    final dashedPath = Path();

    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final double length = (distance + dashLength < metric.length)
            ? dashLength
            : metric.length - distance;
        dashedPath.addPath(
          metric.extractPath(distance, distance + length),
          Offset.zero,
        );
        distance += dashLength + dashGap;
      }
    }

    canvas.drawPath(dashedPath, paint);
  }

  @override
  bool shouldRepaint(covariant DashedRoundedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.radius != radius ||
        oldDelegate.dashLength != dashLength ||
        oldDelegate.dashGap != dashGap;
  }
}
