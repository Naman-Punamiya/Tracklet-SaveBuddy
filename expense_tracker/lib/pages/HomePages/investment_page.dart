import 'package:expense_tracker/constant.dart';
import 'package:flutter/material.dart';

class InvestmentPage extends StatefulWidget {
  const InvestmentPage({super.key});

  @override
  State<InvestmentPage> createState() => _InvestmentPageState();
}

class _InvestmentPageState extends State<InvestmentPage> {

  late Future<List<dynamic>> _investmentsFuture;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Investments'),
      ),
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
            return ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index] as Map<String, dynamic>;
                return ListTile(
                  title: Text(item['name']),
                  subtitle: Text('Amount: \$${item['amount']}'),
                );
              },
            );
          }
        },
      ),
    );
  }

  Future<List<dynamic>> fetchInvestments() async {

    final url = Uri.parse('${investmentUrl}readall');
    // Simulate fetching data from an API
    await Future.delayed(const Duration(seconds: 2));
    return [
      {'name': 'Stock A', 'amount': 1000},
      {'name': 'Stock B', 'amount': 2000},
      {'name': 'Stock C', 'amount': 1500},
    ];
  }
}