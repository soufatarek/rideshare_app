import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: ListView(
        children: [
          _buildSectionHeader('Account'),
          _buildSettingItem(
            Icons.person,
            'Edit Account',
            () => context.push('/edit-profile'),
          ),
          _buildSettingItem(
            Icons.star,
            'Saved Places',
            () => context.push('/saved-places'),
          ),
          _buildSectionHeader('Preferences'),
          _buildSettingItem(
            Icons.privacy_tip,
            'Privacy',
            () => context.push('/privacy'),
          ),
          _buildSettingItem(
            Icons.lock,
            'Security',
            () => context.push('/security'),
          ),
          _buildSettingItem(
            Icons.notifications,
            'Notifications',
            () => context.push('/notifications'),
          ),
          _buildSectionHeader('More'),
          _buildSettingItem(Icons.logout, 'Log Out', () {
            ref.read(authProvider.notifier).signOut();
            context.go('/');
          }, isRed: true),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black54,
        ),
      ),
    );
  }

  Widget _buildSettingItem(
    IconData icon,
    String title,
    VoidCallback onTap, {
    bool isRed = false,
  }) {
    return ListTile(
      leading: Icon(icon, color: isRed ? Colors.red : Colors.black),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: isRed ? Colors.red : Colors.black,
        ),
      ),
      onTap: onTap,
    );
  }
}
