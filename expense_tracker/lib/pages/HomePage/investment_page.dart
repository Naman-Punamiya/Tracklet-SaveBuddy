import 'dart:async';
import 'dart:convert';

import 'package:expense_tracker/core/theme/app_colors.dart';
import 'package:expense_tracker/core/theme/app_dimensions.dart';
import 'package:expense_tracker/core/theme/app_radius.dart';
import 'package:expense_tracker/core/theme/app_shadows.dart';
import 'package:expense_tracker/core/theme/app_spacing.dart';
import 'package:expense_tracker/core/theme/app_text_theme.dart';
import 'package:expense_tracker/core/widgets/app_empty_state.dart';
import 'package:expense_tracker/core/widgets/app_loading.dart';
import 'package:expense_tracker/repositories/repository.dart';
import 'package:expense_tracker/services/connectivity_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class InvestmentPage extends StatefulWidget {
  final String email;
  final String password;
  const InvestmentPage({
    super.key,
    required this.email,
    required this.password,
  });

  @override
  State<InvestmentPage> createState() => _InvestmentPageState();
}

class _InvestmentPageState extends State<InvestmentPage> {
  final InvestmentRepository investmentRepo = InvestmentRepository();

  late Future<List<dynamic>> _investmentsFuture;
  final TextEditingController investmentDescriptionController =
      TextEditingController();
  final TextEditingController investmentAmountController =
      TextEditingController();
  final TextEditingController searchController = TextEditingController();
  StreamSubscription<ConnectivityStatus>? _connectivitySubscription;

  List<dynamic> allInvestments = [];
  List<dynamic> filteredInvestments = [];
  bool isSearching = false;

  final currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  String get basicAuth =>
      'Basic ${base64Encode(utf8.encode('${widget.email}:${widget.password}'))}';

  @override
  void initState() {
    super.initState();
    _investmentsFuture = fetchInvestments();
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
      _reloadInvestments();
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    investmentDescriptionController.dispose();
    investmentAmountController.dispose();
    searchController.dispose();
    super.dispose();
  }

  void _reloadInvestments() {
    setState(() {
      _investmentsFuture = fetchInvestments();
    });
  }

  Future<List<dynamic>> fetchInvestments() async {
    return await investmentRepo.getInvestments();
  }

  Future<void> addInvestment(String description, double amount) async {
    await investmentRepo.addInvestment(description, amount, basicAuth);
  }

  Future<void> updateInvestment(
    String id,
    String description,
    double amount,
  ) async {
    await investmentRepo.updateInvestment(id, description, amount, basicAuth);
  }

  Future<void> deleteInvestment(String id) async {
    await investmentRepo.deleteInvestment(id, basicAuth);
  }

  double _calculateTotalInvested(List<dynamic> items) {
    double total = 0.0;
    for (var item in items) {
      total += (item['amount'] as num?)?.toDouble() ?? 0.0;
    }
    return total;
  }

  Widget _buildInvestmentSummaryCard(double totalInvested, int count) {
    return Container(
      width: double.infinity,
      padding: AppSpacing.p20,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.xLarge,
        boxShadow: const [
          BoxShadow(
            color: Color(0x333EAD91),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "INVESTMENT SUMMARY",
                style: AppTextTheme.labelSmall.copyWith(
                  color: Colors.white.withValues(alpha: 0.8),
                  letterSpacing: 1.2,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: AppRadius.pill,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.folder_rounded,
                      color: AppColors.textWhite,
                      size: 13,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "$count Investments${count == 1 ? '' : 's'}",
                      style: const TextStyle(
                        color: AppColors.textWhite,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.medium),
          Container(
            padding: AppSpacing.p12,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: AppRadius.medium,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Invested Amount",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .8),
                        fontSize: 12,
                      ),
                    ),

                    const SizedBox(height: 2),

                    Text(
                      currencyFormat.format(totalInvested),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),

                Container(
                  width: 1,
                  height: 40,
                  color: Colors.white.withValues(alpha: .3),
                ),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "Investments",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .8),
                        fontSize: 12,
                      ),
                    ),

                    const SizedBox(height: 2),

                    Text(
                      "$count",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _applySearch() {
    final query = searchController.text.trim().toLowerCase();

    setState(() {
      if (query.isEmpty) {
        filteredInvestments = List.from(allInvestments);
      } else {
        filteredInvestments = allInvestments.where((item) {
          final name = (item['description'] ?? '').toString().toLowerCase();
          final amount = (item['amount'] ?? '').toString().toLowerCase();

          return name.contains(query) || amount.contains(query);
        }).toList();
      }
    });
  }

  Widget _buildInvestmentItemCard(Map<String, dynamic> item) {
    final String name = item['description']?.toString() ?? 'Investment';
    final double amount = (item['amount'] as num?)?.toDouble() ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.small),
      decoration: BoxDecoration(
        color: AppColors.lightCard,
        borderRadius: AppRadius.large,
        boxShadow: AppShadows.cardShadowList,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.large,
        child: InkWell(
          borderRadius: AppRadius.large,
          onTap: () => _showInvestmentDetails(item),
          child: Padding(
            padding: AppSpacing.p16,
            child: Row(
              children: [
                Container(
                  width: AppDimensions.avatarSize48,
                  height: AppDimensions.avatarSize48,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryTint,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.trending_up_rounded,
                      color: AppColors.primary,
                      size: AppDimensions.icon24,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.medium),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: AppTextTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      currencyFormat.format(amount),
                      style: AppTextTheme.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: AppColors.lightBackground,
        surfaceTintColor: AppColors.lightBackground,
        elevation: 0,
        title: isSearching
            ? Container(
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.lightSurface,
                  borderRadius: AppRadius.medium,
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: TextField(
                  controller: searchController,
                  autofocus: true,
                  style: AppTextTheme.bodyLarge,
                  decoration: InputDecoration(
                    hintText: "Search investments...",
                    hintStyle: AppTextTheme.bodyMedium.copyWith(
                      color: AppColors.textMuted,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(
                        Icons.clear_rounded,
                        color: AppColors.textSecondary,
                        size: 18,
                      ),
                      onPressed: () {
                        searchController.clear();
                        _applySearch();
                      },
                    ),
                  ),
                  onChanged: (val) => _applySearch(),
                ),
              )
            : Text('Investments', style: AppTextTheme.displayLarge),
        toolbarHeight: 70,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 6),
            decoration: const BoxDecoration(
              color: AppColors.primaryTint,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              iconSize: AppDimensions.icon20,
              tooltip: isSearching ? "Close Search" : "Search",
              onPressed: () {
                setState(() {
                  isSearching = !isSearching;
                  if (!isSearching) {
                    searchController.clear();
                    _applySearch();
                  }
                });
              },
              icon: Icon(
                isSearching ? Icons.close_rounded : Icons.search_rounded,
                color: AppColors.primary,
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: const BoxDecoration(
              color: AppColors.primaryTint,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              iconSize: AppDimensions.icon20,
              tooltip: "Refresh",
              onPressed: _reloadInvestments,
              icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _investmentsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoading();
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading investments: ${snapshot.error}',
                style: AppTextTheme.bodyMedium,
              ),
            );
          }

          allInvestments = snapshot.data ?? [];
          if (searchController.text.isEmpty) {
            filteredInvestments = List.from(allInvestments);
          }
          if (allInvestments.isEmpty) {
            return AppEmptyState(
              icon: Icons.trending_up_rounded,
              title: "No Investments Yet",
              description:
                  "Keep track of your investments by adding your first investment.",
              buttonLabel: "Add Investment",
              onButtonPressed: _showAddInvestmentDialog,
            );
          }

          final double totalInvested = _calculateTotalInvested(allInvestments);
          final investmentTotals = generateInvestmentTotals(allInvestments);
          return ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.medium,
              AppSpacing.xSmall,
              AppSpacing.medium,
              100,
            ),
            children: [
              _buildInvestmentSummaryCard(totalInvested, allInvestments.length),

              const SizedBox(height: AppSpacing.medium),

              buildInvestmentPieChart(investmentTotals),

              const SizedBox(height: AppSpacing.large),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "INVESTMENTS",
                    style: AppTextTheme.labelSmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.small),

              if (filteredInvestments.isEmpty)
                const AppEmptyState(
                  icon: Icons.search_off_rounded,
                  title: "No matching investments",
                  description: "Try another search term.",
                )
              else
                ...filteredInvestments.map(
                  (item) =>
                      _buildInvestmentItemCard(item as Map<String, dynamic>),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_investment_fab',
        backgroundColor: AppColors.primary,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.pill),
        onPressed: _showAddInvestmentDialog,
        icon: const Icon(
          Icons.add_rounded,
          color: AppColors.textWhite,
          size: AppDimensions.icon24,
        ),
        label: const Text("Add Investment", style: AppTextTheme.buttonText),
      ),
    );
  }

  Future<void> _deleteInvestment(String id, BuildContext dialogContext) async {
    Navigator.pop(dialogContext);

    await deleteInvestment(id);

    if (!mounted) return;

    _reloadInvestments();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Investment deleted successfully."),
        backgroundColor: AppColors.expense,
      ),
    );
  }

  void _showAddInvestmentDialog() {
    investmentDescriptionController.clear();
    investmentAmountController.clear();
    String? descriptionError;
    String? amountError;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, dialogSetState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: AppRadius.xLarge),
            backgroundColor: AppColors.lightSurface,
            title: Row(
              children: const [
                Icon(
                  Icons.add_chart_rounded,
                  color: AppColors.primary,
                  size: AppDimensions.icon24,
                ),
                SizedBox(width: AppSpacing.small),
                Text("Add Investment", style: AppTextTheme.titleLarge),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: investmentDescriptionController,
                  style: AppTextTheme.bodyLarge,
                  decoration: InputDecoration(
                    labelText: 'Investment Name',
                    errorText: descriptionError,
                    prefixIcon: const Icon(
                      Icons.description_outlined,
                      size: AppDimensions.icon20,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.medium),
                TextField(
                  controller: investmentAmountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: AppTextTheme.bodyLarge,
                  decoration: InputDecoration(
                    labelText: 'Invested Amount (₹)',
                    errorText: amountError,
                    prefixIcon: const Icon(
                      Icons.currency_rupee_rounded,
                      size: AppDimensions.icon20,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(
                  "Cancel",
                  style: AppTextTheme.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  dialogSetState(() {
                    descriptionError = null;
                    amountError = null;
                  });

                  final description = investmentDescriptionController.text
                      .trim();
                  final amountText = investmentAmountController.text.trim();
                  final amount = double.tryParse(amountText);

                  bool isValid = true;
                  if (description.isEmpty) {
                    dialogSetState(() {
                      descriptionError = "Investment name must not be empty";
                    });
                    isValid = false;
                  }
                  if (amountText.isEmpty) {
                    dialogSetState(() {
                      amountError = "Amount must not be empty";
                    });
                    isValid = false;
                  } else if (amount == null || amount <= 0) {
                    dialogSetState(() {
                      amountError = "Enter a valid amount";
                    });
                    isValid = false;
                  }

                  if (!isValid) return;

                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(dialogContext);

                  await addInvestment(description, amount!);

                  if (!mounted) return;

                  _reloadInvestments();

                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text("Investment added successfully."),
                      backgroundColor: AppColors.income,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textWhite,
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.medium),
                ),
                child: const Text("Add"),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditInvestmentDialog(
    String id,
    String currentInvestmentDescription,
    double currentInvestmentAmount,
  ) {
    investmentDescriptionController.text = currentInvestmentDescription;
    investmentAmountController.text = currentInvestmentAmount.toString();
    String? descriptionError;
    String? amountError;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, dialogSetState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: AppRadius.xLarge),
            backgroundColor: AppColors.lightSurface,
            title: Row(
              children: const [
                Icon(
                  Icons.edit_note_rounded,
                  color: AppColors.primary,
                  size: AppDimensions.icon24,
                ),
                SizedBox(width: AppSpacing.small),
                Text("Edit Investment", style: AppTextTheme.titleLarge),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: investmentDescriptionController,
                  style: AppTextTheme.bodyLarge,
                  decoration: InputDecoration(
                    labelText: 'Investment Name / Type',
                    errorText: descriptionError,
                    prefixIcon: const Icon(
                      Icons.description_outlined,
                      size: AppDimensions.icon20,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.medium),
                TextField(
                  controller: investmentAmountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: AppTextTheme.bodyLarge,
                  decoration: InputDecoration(
                    labelText: 'Invested Amount (₹)',
                    errorText: amountError,
                    prefixIcon: const Icon(
                      Icons.currency_rupee_rounded,
                      size: AppDimensions.icon20,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(
                  "Cancel",
                  style: AppTextTheme.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  dialogSetState(() {
                    descriptionError = null;
                    amountError = null;
                  });

                  final description = investmentDescriptionController.text
                      .trim();
                  final amountText = investmentAmountController.text.trim();
                  final amount = double.tryParse(amountText);

                  bool isValid = true;
                  if (description.isEmpty) {
                    dialogSetState(() {
                      descriptionError = "Investment name must not be empty";
                    });
                    isValid = false;
                  }
                  if (amountText.isEmpty) {
                    dialogSetState(() {
                      amountError = "Amount must not be empty";
                    });
                    isValid = false;
                  } else if (amount == null || amount <= 0) {
                    dialogSetState(() {
                      amountError = "Enter a valid amount";
                    });
                    isValid = false;
                  }

                  if (!isValid) return;

                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(dialogContext);

                  await updateInvestment(id, description, amount!);

                  if (!mounted) return;

                  _reloadInvestments();

                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text("Investment updated successfully."),
                      backgroundColor: AppColors.income,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textWhite,
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.medium),
                ),
                child: const Text("Save"),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showInvestmentDetails(Map<String, dynamic> item) {
    final String name = item['description']?.toString() ?? '';
    final double amount = (item['amount'] as num?)?.toDouble() ?? 0.0;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.xLarge),
        backgroundColor: AppColors.lightSurface,
        title: Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: AppTextTheme.titleLarge,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.small),
            Container(
              padding: AppSpacing.p12,
              decoration: BoxDecoration(
                color: AppColors.lightBackground,
                borderRadius: AppRadius.medium,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Invested Amount:",
                    style: AppTextTheme.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    currencyFormat.format(amount),
                    style: AppTextTheme.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _showEditInvestmentDialog(item['id'].toString(), name, amount);
            },
            child: const Text(
              "Edit",
              style: TextStyle(color: AppColors.primary),
            ),
          ),
          TextButton(
            onPressed: () async {
              await _deleteInvestment(item['id'].toString(), dialogContext);
            },
            child: const Text(
              "Delete",
              style: TextStyle(color: AppColors.expense),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              "Close",
              style: AppTextTheme.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildInvestmentPieChart(Map<String, double> investmentTotals) {
    final total = investmentTotals.values.fold(0.0, (a, b) => a + b);

    return Container(
      padding: AppSpacing.p20,
      decoration: BoxDecoration(
        color: AppColors.lightCard,
        borderRadius: AppRadius.xLarge,
        boxShadow: AppShadows.cardShadowList,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Investment Distribution",
            style: AppTextTheme.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 20),

          SizedBox(
            height: 240,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    centerSpaceRadius: 60,
                    centerSpaceColor: Colors.white,
                    sectionsSpace: 3,
                    borderData: FlBorderData(show: false),

                    sections: List.generate(investmentTotals.length, (index) {
                      final value = investmentTotals.values.elementAt(index);

                      final percentage = (value / total) * 100;

                      return PieChartSectionData(
                        value: value,
                        title: "${percentage.toStringAsFixed(0)}%",
                        color: pieColors[index % pieColors.length],
                        radius: 55,
                        titleStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      );
                    }),
                  ),
                ),

                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Total",
                      style: AppTextTheme.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),

                    Text(
                      currencyFormat.format(total),
                      style: AppTextTheme.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          Wrap(
            spacing: 16,
            runSpacing: 10,
            children: List.generate(investmentTotals.length, (index) {
              final key = investmentTotals.keys.elementAt(index);

              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: pieColors[index % pieColors.length],
                        shape: BoxShape.circle,
                      ),
                    ),

                    const SizedBox(width: 6),

                    Expanded(child: Text(key, overflow: TextOverflow.ellipsis)),

                    Text(currencyFormat.format(investmentTotals[key]!)),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Map<String, double> generateInvestmentTotals(List<dynamic> investments) {
    final Map<String, double> totals = {};

    for (final item in investments) {
      final String name = (item['description'] ?? 'Unknown').toString();

      final double amount = (item['amount'] as num?)?.toDouble() ?? 0.0;

      totals.update(name, (value) => value + amount, ifAbsent: () => amount);
    }

    return totals;
  }
}
