import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class HomeDrawer extends ConsumerWidget {
  const HomeDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final userName =
        user != null ? '${user.firstName} ${user.lastName}' : 'Guest';
    final userEmail = user?.email ?? '';

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: Colors.black),
            accountName: Text(
              userName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            accountEmail: Text(userEmail),
            currentAccountPicture: GestureDetector(
              onTap: () {
                context.pop(); // Close drawer
                context.push('/profile');
              },
              child: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.person, size: 40, color: Colors.black),
              ),
            ),
          ),
          _buildDrawerItem(Icons.payment, 'Payment', () {
            context.pop();
            context.push('/wallet');
          }),
          _buildDrawerItem(Icons.history, 'Trips', () {
            context.pop(); // Close drawer
            context.push('/trips');
          }),
          _buildDrawerItem(Icons.help, 'Help', () {}),
          _buildDrawerItem(Icons.settings, 'Settings', () {
            context.pop(); // Close drawer
            context.push('/settings');
          }),
          const Divider(),
          _buildDrawerItem(Icons.drive_eta, 'Drive with Uber', () {}),
          _buildDrawerItem(Icons.local_offer, 'Promotions', () {}),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.black),
      title: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
      onTap: onTap,
    );
  }
}
