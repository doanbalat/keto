import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'services/localization_service.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(LocalizationService.getString('nav_privacy')),
        backgroundColor: Colors.black26,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // External Policy Link
            Card(
              color: Colors.blue.withValues(alpha: 0.1),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.link, color: Colors.blue, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Full Privacy Policy',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () {
                              launchUrl(
                                Uri.parse('https://github.com/doanbalat/docs/blob/main/keto/privacy-policy.md'),
                                mode: LaunchMode.externalApplication,
                              );
                            },
                            child: const Text(
                              'View on GitHub →',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.lightBlue,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionCard(
              icon: Icons.verified_user,
              title: LocalizationService.getString('privacy_access_title'),
              content: LocalizationService.getString('privacy_access_content'),
              color: Colors.green,
            ),
            _buildSectionCard(
              icon: Icons.security,
              title: LocalizationService.getString('privacy_data_title'),
              content: LocalizationService.getString('privacy_data_content'),
              color: Colors.blue,
            ),
            _buildSectionCard(
              icon: Icons.storage,
              title: LocalizationService.getString('privacy_export_title'),
              content: LocalizationService.getString('privacy_export_content'),
              color: Colors.orange,
            ),
            _buildSectionCard(
              icon: Icons.delete_forever,
              title: LocalizationService.getString('privacy_delete_title'),
              content: LocalizationService.getString('privacy_delete_content'),
              color: Colors.red,
            ),
            _buildSectionCard(
              icon: Icons.email,
              title: LocalizationService.getString('privacy_contact_title'),
              content: LocalizationService.getString('privacy_contact_content'),
              color: Colors.purple,
            ),
            const SizedBox(height: 32),
            // Version footer
            Center(
              child: Text(
                'v${LocalizationService.appVersion}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required String content,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border(
              left: BorderSide(
                color: color,
                width: 5,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        icon,
                        color: color,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  content,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
