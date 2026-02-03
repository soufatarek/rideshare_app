import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class SecurityScreen extends ConsumerStatefulWidget {
  const SecurityScreen({super.key});

  @override
  ConsumerState<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends ConsumerState<SecurityScreen> {
  bool _twoFactorEnabled = false;
  bool _biometricEnabled = false; // Default off

  @override
  void initState() {
    super.initState();
    _loadBiometricSettings();
  }

  Future<void> _loadBiometricSettings() async {
    final enabled = await ref.read(authProvider.notifier).isBiometricEnabled();
    if (mounted) {
      setState(() {
        _biometricEnabled = enabled;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Security', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Login Security',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.password, color: Colors.black),
            title: const Text('Change Password'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Password change flow would start here.'),
                ),
              );
            },
          ),
          SwitchListTile(
            activeColor: AppColors.primary,
            title: const Text('Biometric Login'),
            subtitle: const Text('Use FaceID / Fingerprint to login'),
            value: _biometricEnabled,
            onChanged: (val) async {
              final notifier = ref.read(authProvider.notifier);
              if (val) {
                // Try to authenticate to enable
                final success = await notifier.authenticateWithBiometrics();
                if (success) {
                  await notifier.setBiometricEnabled(true);
                  if (mounted) {
                    setState(() => _biometricEnabled = true);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Biometrics Enabled')),
                    );
                  }
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Authentication failed or hardware unavailable.',
                        ),
                      ),
                    );
                  }
                }
              } else {
                await notifier.setBiometricEnabled(false);
                if (mounted) {
                  setState(() => _biometricEnabled = false);
                }
              }
            },
          ),
          SwitchListTile(
            activeColor: AppColors.primary,
            title: const Text('Two-Factor Authentication'),
            subtitle: const Text('Add an extra layer of security'),
            value: _twoFactorEnabled,
            onChanged: (val) => setState(() => _twoFactorEnabled = val),
          ),
          const Divider(height: 48),

          const Text(
            'Account Actions',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text(
              'Delete Account',
              style: TextStyle(color: Colors.red),
            ),
            onTap: _showDeleteConfirmation,
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Account?'),
            content: const Text(
              'This action is irreversible. All your data, trips, and saved places will be permanently deleted.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  // Actual delete logic would go here
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Account deletion requested.'),
                    ),
                  );
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }
}
