import 'package:flutter/material.dart';
import '../../constants/app_theme.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 24),
            _buildSection(context, '1. Information We Collect', '''
We collect the following types of information:

Personal Information:
• Name, email address, phone number
• Date of birth, gender, address
• Profile picture (optional)

Health Information:
• Heart rate readings
• ECG waveform data
• Session timestamps and duration
• Weight and height

Device Information:
• Bluetooth device identifier
• App usage analytics (anonymized)'''),
            _buildSection(context, '2. How We Use Your Data', '''
We use collected data to:
• Provide and improve the App's features
• Generate personalized health insights
• Sync data across your devices
• Send health alerts and notifications
• Comply with legal obligations

We do NOT sell your personal or health data to third parties.'''),
            _buildSection(context, '3. Data Storage', '''
Profile Data (Cloud): Your profile information is securely stored in our Supabase cloud database with row-level security, ensuring only you can access your data.

Health Data (Local): ECG recordings, heart rate history, and session logs are stored locally on your device using encrypted Hive storage. This data is not uploaded to our servers by default.'''),
            _buildSection(context, '4. Data Security', '''
We implement industry-standard security measures:
• AES-256 encryption for data at rest
• TLS 1.3 for data in transit
• Row-level security in cloud database
• Regular security audits
• Automatic session expiration'''),
            _buildSection(context, '5. Your Rights', '''
You have the right to:
• Access your personal data at any time
• Correct inaccurate data
• Delete your account and all associated data
• Export your health data
• Opt out of analytics collection

To exercise these rights, contact us at privacy@inteliwave.com'''),
            _buildSection(context, '6. Third-Party Services', '''
We use the following third-party services:
• Supabase — Cloud database and authentication
• Google Sign-In — Optional authentication method

These services have their own privacy policies that govern their use of your data.'''),
            _buildSection(context, '7. Children\'s Privacy', '''
IntelIWave is not intended for users under 13 years of age. We do not knowingly collect data from children. If you believe a child has provided us with personal information, please contact us immediately.'''),
            _buildSection(context, '8. Contact Us', '''
Privacy Officer: privacy@inteliwave.com
Address: IntelIWave Inc., Colombo, Sri Lanka'''),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.success.withOpacity(0.1),
            AppColors.success.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.success,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.privacy_tip, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Privacy Policy',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                    ),
              ),
              Text(
                'Last updated: June 2025',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.grey,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.success,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.7,
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppColors.darkGrey,
                ),
          ),
          const Divider(height: 32),
        ],
      ),
    );
  }
}
