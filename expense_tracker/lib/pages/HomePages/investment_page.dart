import 'dart:convert';

import 'package:expense_tracker/constant.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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
  late Future<List<dynamic>> _investmentsFuture;

  String get basicAuth =>
      'Basic ${base64Encode(utf8.encode('${widget.email}:${widget.password}'))}';

  @override
  initState() {
    super.initState();
    _investmentsFuture = fetchInvestments();
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Investments')),
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
                return Card(
                  child: ListTile(
                    trailing: Text(
                      '₹${item['amount']}',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 24,
                      ),
                    ),
                    minTileHeight: 70,
                    tileColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade300, width: 1),
                    ),
                
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
            );
          }
        },
      ),
    );
  }

  Future<List<dynamic>> fetchInvestments() async {
    final url = Uri.parse('${investmentUrl}readAll');

    final res = await http.get(
      url,
      headers: {'Authorization': basicAuth, 'Content-Type': 'application/json'},
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to load investments');
    }
    return jsonDecode(res.body);
  }
}
