import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_theme.dart';
import '../../providers/settings_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Appearance',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Consumer<SettingsProvider>(
              builder: (context, settingsProvider, _) {
                String themeName = 'System';
                switch (settingsProvider.themeMode) {
                  case ThemeMode.light:
                    themeName = 'Light';
                    break;
                  case ThemeMode.dark:
                    themeName = 'Dark';
                    break;
                  case ThemeMode.system:
                    themeName = 'System';
                    break;
                }
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _SettingsTile(
                          title: 'Theme',
                          subtitle: themeName,
                          icon: Icons.palette,
                          onTap: () => _showThemeDialog(context, settingsProvider),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              'Notifications',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Consumer<SettingsProvider>(
              builder: (context, settingsProvider, _) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        _NotificationToggleTile(
                          title: 'Enable Notifications',
                          value: settingsProvider.notificationsEnabled,
                          onChanged: (value) {
                            settingsProvider.setNotificationsEnabled(value);
                          },
                        ),
                        const Divider(),
                        _NotificationToggleTile(
                          title: 'Heart Rate Alerts',
                          value: settingsProvider.heartRateAlertsEnabled,
                          onChanged: (value) {
                            settingsProvider.setHeartRateAlertsEnabled(value);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              'About',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _InfoTile(label: 'App Name', value: 'IntelIWave'),
                    const Divider(),
                    _InfoTile(label: 'Version', value: '1.0.0'),
                    const Divider(),
                    _InfoTile(
                      label: 'Build',
                      value: DateTime.now().toString().split('.')[0],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Help & Support',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  _SettingsTile(
                    title: 'Help & FAQ',
                    icon: Icons.help_outline,
                    subtitle: 'Find answers to common questions',
                    onTap: () => Navigator.pushNamed(context, '/help'),
                  ),
                  const Divider(height: 1, indent: 56),
                  _SettingsTile(
                    title: 'Contact Us',
                    icon: Icons.support_agent,
                    subtitle: 'Get in touch with our team',
                    onTap: () => Navigator.pushNamed(context, '/contact'),
                  ),
                  const Divider(height: 1, indent: 56),
                  _SettingsTile(
                    title: 'Privacy Policy',
                    icon: Icons.privacy_tip_outlined,
                    subtitle: 'How we handle your data',
                    onTap: () => Navigator.pushNamed(context, '/privacy'),
                  ),
                  const Divider(height: 1, indent: 56),
                  _SettingsTile(
                    title: 'Terms & Conditions',
                    icon: Icons.gavel,
                    subtitle: 'Read our terms of service',
                    onTap: () => Navigator.pushNamed(context, '/terms'),
                  ),
                ],
              ),
            ),

          ],
        ),
      ),
    );
  }

  void _showThemeDialog(BuildContext context, SettingsProvider settingsProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<ThemeMode>(
              title: const Text('Light'),
              value: ThemeMode.light,
              groupValue: settingsProvider.themeMode,
              onChanged: (value) {
                if (value != null) {
                  settingsProvider.setThemeMode(value);
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('Dark'),
              value: ThemeMode.dark,
              groupValue: settingsProvider.themeMode,
              onChanged: (value) {
                if (value != null) {
                  settingsProvider.setThemeMode(value);
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('System'),
              value: ThemeMode.system,
              groupValue: settingsProvider.themeMode,
              onChanged: (value) {
                if (value != null) {
                  settingsProvider.setThemeMode(value);
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.title,
    required this.icon,
    required this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _NotificationToggleTile extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _NotificationToggleTile({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;

  const _InfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.grey,
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }
}
