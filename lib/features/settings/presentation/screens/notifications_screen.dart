import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _pushEnabled = prefs.getBool('notif_push') ?? true;
      _emailEnabled = prefs.getBool('notif_email') ?? false;
      _promoEnabled = prefs.getBool('notif_promo') ?? true;
      _isLoading = false;
    });
  }

  Future<void> _savePreference(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Notifications', style: TextStyle(color: Colors.black)),
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

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
            onChanged: (val) {
              setState(() => _pushEnabled = val);
              _savePreference('notif_push', val);
            },
          ),
          const Divider(),
          SwitchListTile(
            activeColor: AppColors.primary,
            title: const Text('Email Updates'),
            subtitle: const Text('Trip receipts and support updates.'),
            value: _emailEnabled,
            onChanged: (val) {
              setState(() => _emailEnabled = val);
              _savePreference('notif_email', val);
            },
          ),
          const Divider(),
          SwitchListTile(
            activeColor: AppColors.primary,
            title: const Text('Promotions & Offers'),
            subtitle: const Text('Get notified about discounts and news.'),
            value: _promoEnabled,
            onChanged: (val) {
              setState(() => _promoEnabled = val);
              _savePreference('notif_promo', val);
            },
          ),
        ],
      ),
    );
  }
}
