import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Modern App Bar with gradient
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.blue[600]!,
                      Colors.blue[400]!,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: const Icon(
                        Icons.person,
                        size: 60,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Keto',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Bio Section
                  _buildSectionCard(
                    title: 'About Keto',
                    isDarkMode: isDarkMode,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Keto is a modern sales, expense, and inventory management app designed for small business owners.',
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.6,
                            color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Track your sales, manage expenses, monitor inventory, and view analytics — all in one beautiful app.',
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.6,
                            color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Version & Info Section
                  _buildSectionCard(
                    title: 'App Info',
                    isDarkMode: isDarkMode,
                    child: Column(
                      children: [
                        _buildInfoRow(
                          label: 'Version',
                          value: '1.0.0',
                          isDarkMode: isDarkMode,
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          label: 'Status',
                          value: 'Free Version',
                          isDarkMode: isDarkMode,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Support Section
                  _buildSectionCard(
                    title: 'Support & Donation',
                    isDarkMode: isDarkMode,
                    child: Column(
                      children: [
                        _buildActionButton(
                          label: 'Buy Me a Coffee',
                          icon: Icons.local_cafe,
                          color: Colors.orange,
                          isDarkMode: isDarkMode,
                          onTap: () {
                            // Donation link will be added later
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildActionButton(
                          label: 'GitHub Repository',
                          icon: Icons.code,
                          color: Colors.grey[700]!,
                          isDarkMode: isDarkMode,
                          onTap: () {
                            // GitHub link will be added later
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildActionButton(
                          label: 'Contact Us',
                          icon: Icons.mail,
                          color: Colors.blue,
                          isDarkMode: isDarkMode,
                          onTap: () {
                            // Contact link will be added later
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Social Links (Placeholder)
                  _buildSectionCard(
                    title: 'Connect',
                    isDarkMode: isDarkMode,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildSocialIcon(
                          icon: Icons.language,
                          label: 'Website',
                          isDarkMode: isDarkMode,
                        ),
                        _buildSocialIcon(
                          icon: Icons.facebook,
                          label: 'Facebook',
                          isDarkMode: isDarkMode,
                        ),
                        _buildSocialIcon(
                          icon: Icons.phone,
                          label: 'Phone',
                          isDarkMode: isDarkMode,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Footer
                  Center(
                    child: Text(
                      '© 2025 Keto. All rights reserved.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required bool isDarkMode,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.grey[900] : Colors.grey[50],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDarkMode ? Colors.grey[800]! : Colors.grey[200]!,
              width: 1,
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: child,
        ),
      ],
    );
  }

  Widget _buildInfoRow({
    required String label,
    required String value,
    required bool isDarkMode,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.grey[200] : Colors.grey[800],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required bool isDarkMode,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_outward,
                color: color,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSocialIcon({
    required IconData icon,
    required String label,
    required bool isDarkMode,
  }) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.grey[800] : Colors.grey[100],
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            icon,
            color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
            size: 28,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
