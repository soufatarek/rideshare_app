import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _pushEnabled = true;
  bool _emailEnabled = false;
  bool _promoEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            activeColor: AppColors.primary,
            title: const Text('Push Notifications'),
            subtitle: const Text('Receive alerts about your rides.'),
            value: _pushEnabled,
            onChanged: (val) => setState(() => _pushEnabled = val),
          ),
          const Divider(),
          SwitchListTile(
            activeColor: AppColors.primary,
            title: const Text('Email Updates'),
            subtitle: const Text('Trip receipts and support updates.'),
            value: _emailEnabled,
            onChanged: (val) => setState(() => _emailEnabled = val),
          ),
          const Divider(),
          SwitchListTile(
            activeColor: AppColors.primary,
            title: const Text('Promotions & Offers'),
            subtitle: const Text('Get notified about discounts and news.'),
            value: _promoEnabled,
            onChanged: (val) => setState(() => _promoEnabled = val),
          ),
        ],
      ),
    );
  }
}
