import 'dart:async';
import 'dart:convert';

import 'package:expense_tracker/repositories/repository.dart';
import 'package:expense_tracker/services/connectivity_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

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
  TextEditingController investmentDescriptionController =
      TextEditingController();
  TextEditingController investmentAmountController = TextEditingController();
  StreamSubscription<ConnectivityStatus>? _connectivitySubscription;

  String get basicAuth =>
      'Basic ${base64Encode(utf8.encode('${widget.email}:${widget.password}'))}';

  @override
  void initState() {
    super.initState();
    _investmentsFuture = fetchInvestments();
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
      _reloadInvestments();
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    investmentDescriptionController.dispose();
    investmentAmountController.dispose();
    super.dispose();
  }

  void _reloadInvestments() {
    setState(() {
      _investmentsFuture = fetchInvestments();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Investments',style: TextStyle(fontWeight: FontWeight.w500, fontSize: 30),),toolbarHeight: 100,),
      body: FutureBuilder<List<dynamic>>(
        future: _investmentsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final items = snapshot.data ?? [];
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No investments found.'));
          } else {
            return Column(
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height/3,
                  child: PieChart(
                    PieChartData(
                      sections: items.map((item) {
                        final amount = (item['amount'] as num?)?.toDouble() ?? 0.0;
                        return PieChartSectionData(
                          value: amount,
                          title: item['description']?.toString() ?? '',
                          color: Colors.primaries[items.indexOf(item) % Colors.primaries.length],
                          radius: 50,
                          titleStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        );
                      }).toList(),
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                    ),
                  )
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index] as Map<String, dynamic>;
                      return Card(
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          onTap: () {
                            _showInvestmentDetails(item);
                          },
                          trailing: Text(
                            '₹${item['amount']}',
                            style: TextStyle(color: Colors.black, fontSize: 24),
                          ),
                          minTileHeight: 70,
                          tileColor: Colors.white,
                  
                          // shape: RoundedRectangleBorder(
                          //   borderRadius: BorderRadius.circular(12),
                          //   side: BorderSide(color: Colors.grey.shade300, width: 1),
                          // ),
                          title: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Text(
                              item['description']?.toString() ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 24,
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
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAddInvestmentDialog();
        },
        child: const Icon(Icons.add),
      ),
    );
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

  Future<void> _deleteInvestment(String id, BuildContext dialogContext) async {
    Navigator.pop(dialogContext);

    await deleteInvestment(id);

    if (!mounted) return;

    _reloadInvestments();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Investment Deleted")));
  }

  void _showAddInvestmentDialog() {
    investmentDescriptionController.clear();
    investmentAmountController.clear();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Add Investment"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: investmentDescriptionController,
              decoration: const InputDecoration(
                labelText: 'Investment Description',
              ),
            ),
            TextField(
              controller: investmentAmountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Investment Amount'),
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

              final amount = double.tryParse(investmentAmountController.text);

              if (amount == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Enter a valid amount")),
                );
                return;
              }

              await addInvestment(investmentDescriptionController.text, amount);

              if (!mounted) return;

              _reloadInvestments();

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Investment Added Successfully")),
              );
            },
            child: const Text("Add"),
          ),
        ],
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

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Edit Investment"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: investmentDescriptionController,
              decoration: const InputDecoration(
                labelText: 'Investment Description',
              ),
            ),
            TextField(
              controller: investmentAmountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Investment Amount'),
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

              await updateInvestment(
                id,
                investmentDescriptionController.text,
                double.parse(investmentAmountController.text),
              );

              if (!mounted) return;

              _reloadInvestments();

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Investment Updated")),
              );
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _showInvestmentDetails(Map<String, dynamic> item) {
    final String investmentDescription = item['description']?.toString() ?? '';
    final double investmentAmount = (item['amount'] as num?)?.toDouble() ?? 0.0;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Investment Details"),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Investment Description: $investmentDescription"),
            Text("Investment Amount: $investmentAmount"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);

              _showEditInvestmentDialog(
                item['id'].toString(),
                investmentDescription,
                investmentAmount,
              );
            },
            child: const Text("Edit"),
          ),
          TextButton(
            onPressed: () async {
              await _deleteInvestment(item['id'].toString(), dialogContext);
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
}
