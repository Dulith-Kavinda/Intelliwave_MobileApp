import 'package:flutter/material.dart';
import '../../constants/app_theme.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms & Conditions'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(
              context,
              icon: Icons.gavel,
              title: 'Terms & Conditions',
              subtitle: 'Last updated: June 2025',
            ),
            const SizedBox(height: 24),
            _buildSection(context, '1. Acceptance of Terms', '''
By downloading, installing, or using the IntelIWave application ("App"), you agree to be bound by these Terms & Conditions. If you do not agree to these terms, please do not use this App.'''),
            _buildSection(context, '2. Medical Disclaimer', '''
IntelIWave is designed for general wellness monitoring purposes only. The App is NOT intended to diagnose, treat, cure, or prevent any medical condition. Always consult a qualified healthcare professional for medical advice.

The ECG data and heart rate readings provided by the App should not be used as a substitute for professional medical diagnosis or treatment.'''),
            _buildSection(context, '3. Device Requirements', '''
The App requires a compatible Bluetooth ECG device to function. IntelIWave is not responsible for the accuracy of third-party hardware devices. Users are responsible for ensuring their device is properly calibrated and maintained.'''),
            _buildSection(context, '4. User Responsibilities', '''
You are responsible for:
• Keeping your account credentials secure
• Providing accurate personal and health information
• Using the App in accordance with applicable laws
• Not sharing your account with others
• Ensuring proper device handling and maintenance'''),
            _buildSection(context, '5. Data & Privacy', '''
We collect and process personal health data as described in our Privacy Policy. By using the App, you consent to data collection as outlined in the Privacy Policy. We implement industry-standard security measures to protect your data.'''),
            _buildSection(context, '6. Intellectual Property', '''
All content, features, and functionality of the IntelIWave App are owned by IntelIWave and protected by international copyright, trademark, and other intellectual property laws.'''),
            _buildSection(context, '7. Limitation of Liability', '''
IntelIWave shall not be liable for any indirect, incidental, special, or consequential damages arising out of or relating to your use of the App. Our total liability shall not exceed the amount paid for the App in the 12 months preceding the claim.'''),
            _buildSection(context, '8. Changes to Terms', '''
We reserve the right to modify these terms at any time. We will notify users of material changes via the App. Continued use after changes constitutes acceptance of the new terms.'''),
            _buildSection(context, '9. Contact', '''
If you have questions about these Terms, please contact us at:
Email: legal@inteliwave.com
Address: IntelIWave Inc., Colombo, Sri Lanka'''),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context,
      {required IconData icon,
      required String title,
      required String subtitle}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.1),
            AppColors.primaryLight.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
              ),
              Text(
                subtitle,
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
                  color: AppColors.primary,
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
