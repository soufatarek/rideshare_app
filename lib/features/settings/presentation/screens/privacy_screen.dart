import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  bool _shareLocation = true;
  bool _allowDataCollection = true;
  bool _visibleToContacts = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildInfoSection(),
          const SizedBox(height: 24),
          const Text(
            'Permissions',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            activeColor: AppColors.primary,
            title: const Text('Share Live Location'),
            subtitle: const Text('Allow driver to see your precise location.'),
            value: _shareLocation,
            onChanged: (val) => setState(() => _shareLocation = val),
          ),
          SwitchListTile(
            activeColor: AppColors.primary,
            title: const Text('Visible to Contacts'),
            subtitle: const Text('Let friends see when you are on a trip.'),
            value: _visibleToContacts,
            onChanged: (val) => setState(() => _visibleToContacts = val),
          ),
          SwitchListTile(
            activeColor: AppColors.primary,
            title: const Text('Data Collection'),
            subtitle: const Text('Help us improve by sharing usage data.'),
            value: _allowDataCollection,
            onChanged: (val) => setState(() => _allowDataCollection = val),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.privacy_tip, color: Colors.blue),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              'Your privacy is important to us. Learn how we handle your data in our Privacy Policy.',
              style: TextStyle(color: Colors.blue, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
