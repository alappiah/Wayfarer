import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Card(
          elevation: 2,
          child: ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Account'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Handle account settings
            },
          ),
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 2,
          child: ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('Notifications'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Handle notification settings
            },
          ),
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 2,
          child: ListTile(
            leading: const Icon(Icons.color_lens),
            title: const Text('Appearance'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Handle appearance settings
            },
          ),
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 2,
          child: ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: const Text('Privacy'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Handle privacy settings
            },
          ),
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 2,
          child: ListTile(
            leading: const Icon(Icons.backup),
            title: const Text('Backup & Restore'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Handle backup settings
            },
          ),
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 2,
          child: ListTile(
            leading: const Icon(Icons.help),
            title: const Text('Help & Support'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Handle help settings
            },
          ),
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 2,
          child: ListTile(
            leading: const Icon(Icons.info),
            title: const Text('About'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Handle about settings
            },
          ),
        ),
      ],
    );
  }
}