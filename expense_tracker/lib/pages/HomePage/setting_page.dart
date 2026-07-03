import 'dart:convert';

import 'package:expense_tracker/custom_widgets/custom_card.dart';
import 'package:expense_tracker/keep_alive_service.dart';
import 'package:expense_tracker/pages/Auth/login_page.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingPage extends StatefulWidget {
  final String email;
  final String password;
  const SettingPage({super.key, required this.email, required this.password});

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  String get basicAuth =>
      'Basic ${base64Encode(utf8.encode('${widget.email}:${widget.password}'))}';
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Settings",
          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 30),
        ),
        toolbarHeight: 100,
      ),
      body: Column(
        children: [
          CustomCard(
            leadingIcon: Icons.person_outline,
            title: 'Account',
            subtitle: 'Update your profile',
            trailingIcon: Icons.arrow_forward,
          ),
          CustomCard(
            leadingIcon: Icons.palette_outlined,
            title: 'Appearance',
            subtitle: 'Customize theme',
            trailingIcon: Icons.arrow_forward,
          ),
          CustomCard(
            leadingIcon: Icons.notifications_outlined,
            title: 'Notifications',
            subtitle: 'Manage notification',
            trailingIcon: Icons.arrow_forward,
          ),
          CustomCard(
            leadingIcon: Icons.money_outlined,
            title: 'Finance',
            subtitle: 'Manage finance',
            trailingIcon: Icons.arrow_forward,
          ),
          CustomCard(
            leadingIcon: Icons.folder_outlined,
            title: 'Data',
            subtitle: 'Manage data',
            trailingIcon: Icons.arrow_forward,
          ),
          CustomCard(
            leadingIcon: Icons.security_outlined,
            title: 'Security',
            subtitle: 'Make your account secure',
            trailingIcon: Icons.arrow_forward,
          ),
          CustomCard(
            leadingIcon: Icons.support_outlined,
            title: 'Support',
            subtitle: 'Get help and support',
            trailingIcon: Icons.arrow_forward,
          ),
          Spacer(),
          Card(
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              minTileHeight: 70,
              tileColor: Colors.red,
              title: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  "Logout",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                    color: Colors.white,
                  ),
                ),
              ),
              onTap: logout,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> logout() async {
    KeepAliveService.stop();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => LoginPage()));
  }
}
