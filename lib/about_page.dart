import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'ad_page.dart';
import 'services/localization_service.dart';
import 'widgets/feedback_form_dialog.dart';
class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  final ScrollController _scrollController = ScrollController();
  late final ValueNotifier<double> _scrollOffset;

  @override
  void initState() {
    super.initState();
    _scrollOffset = ValueNotifier(0);
    _scrollController.addListener(() {
      _scrollOffset.value = _scrollController.offset;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _scrollOffset.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;

    // Responsive heights
    double topBannerHeight;
    double bottomBannerHeight;

    if (isMobile) { // Mobile
      topBannerHeight = screenHeight * 0.35;
      bottomBannerHeight = screenHeight * 0.30;
    } else if (isTablet) { // Tablet
      topBannerHeight = screenHeight * 0.32;
      bottomBannerHeight = screenHeight * 0.25;
    } else { // Desktop
      topBannerHeight = screenHeight * 0.28;
      bottomBannerHeight = screenHeight * 0.20;
    }


    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Modern App Bar with banner background
          SliverAppBar(
            expandedHeight: topBannerHeight,
            floating: false,
            pinned: false,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/images/banner.png',
                    fit: BoxFit.cover,
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.2),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Content with RepaintBoundary to improve performance
          SliverToBoxAdapter(
            child: RepaintBoundary(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: _AboutPageContent(),
              ),
            ),
          ),
          // Bottom banner image - Default SliverAppBar
          SliverAppBar(
            expandedHeight: bottomBannerHeight,
            floating: false,
            pinned: false,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Image.asset(
                'assets/images/banner2.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Main content widget - extracted to separate class for better performance
class _AboutPageContent extends StatefulWidget {
  const _AboutPageContent();

  @override
  State<_AboutPageContent> createState() => _AboutPageContentState();
}

class _AboutPageContentState extends State<_AboutPageContent> {
  // Replace with your actual PayPal email or username
  static const String _paypalUsername = 'doanbalat';

  Future<void> _openPayPalPayment() async {
    // PayPal.Me link - user can choose amount and payment method
    final paypalUrl = 'https://www.paypal.me/$_paypalUsername';
    
    try {
      if (await canLaunchUrl(Uri.parse(paypalUrl))) {
        await launchUrl(
          Uri.parse(paypalUrl),
          mode: LaunchMode.externalApplication,
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open PayPal')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showDonationDialog(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Your Donation Method'),
        contentPadding: const EdgeInsets.all(0),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DonationOption(
                label: 'PayPal',
                icon: Icons.payment,
                color: Colors.blue,
                isDarkMode: isDarkMode,
                onTap: () {
                  Navigator.pop(context);
                  _openPayPalPayment();
                },
              ),
              _DonationOption(
                label: 'Bank Account',
                icon: Icons.account_balance,
                color: Colors.teal,
                isDarkMode: isDarkMode,
                onTap: () {
                  Navigator.pop(context);
                  _showBankQRCode(context);
                },
              ),
              _DonationOption(
                label: 'Ví MoMo',
                icon: Icons.wallet_membership,
                color: Colors.purple,
                isDarkMode: isDarkMode,
                onTap: () {
                  Navigator.pop(context);
                  _showMoMoQRCode(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBankQRCode(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Donate via Bank Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Open your banking app and scan the QR code below:',
              style: TextStyle(fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[800] : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Image.asset(
                'assets/images/bank_qr.jpeg',
                width: 250,
                height: 250,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Text('QR code image not found'),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Thank you for your support! 🙏',
              style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showMoMoQRCode(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Donate via MoMo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Open MoMo app and scan QR code:',
              style: TextStyle(fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[800] : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Image.asset(
                'assets/images/momo_qr.jpeg',
                width: 250,
                height: 250,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Text('QR code image not found'),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Thank you for your support! 🙏',
              style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Bio Section
        _SectionCard(
          title: 'About Keto',
          isDarkMode: isDarkMode,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Feature 1
              _AboutFeature(
                icon: Icons.shopping_bag,
                title: 'For Small Businesses',
                description: 'If your business don\'t need to print receipts or don\'t want to get in too deep statistics, this app is for you my friend :)',
                isDarkMode: isDarkMode,
              ),
              const SizedBox(height: 20),
              // Feature 2
              _AboutFeature(
                icon: Icons.trending_up,
                title: 'Complete Management',
                description: 'The app helps you manage sales, expenses, inventory, and revenue reports in a much much simple way. Intended for "Các cô, các chú bán hàng nhỏ lẻ" and any young entrepreneurs.',
                isDarkMode: isDarkMode,
              ),
              const SizedBox(height: 20),
              // Feature 3
              _AboutFeature(
                icon: Icons.speed,
                title: 'Simple & Fast',
                description: 'Designed to be lightweight and easy to use, the app works completely offline for your convenience.',
                isDarkMode: isDarkMode,
              ),
              const SizedBox(height: 20),
              // Feature 4
              _AboutFeature(
                icon: Icons.security,
                title: 'Why is this app made?',
                description: 'I want a book keeping app for my family business, but couldn\'t find any suitable app that is simple enough for my monke brain. So I decided to make one, happy to share it with everyone else who might need it.',
                isDarkMode: isDarkMode,
              ),
              const SizedBox(height: 20),
              // Feature 5
              _AboutFeature(
                icon: Icons.person,
                title: 'Will this app get updates, more features?',
                description: 'Sure! ;)\nFeel free to give me any suggestions or feedbacks, much appreciated.',
                isDarkMode: isDarkMode,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Support Section
        _SectionCard(
          title: 'Support & Donation',
          isDarkMode: isDarkMode,
          child: Column(
            children: [
              _ActionButton(
                label: 'Buy Me a Coffee',
                icon: Icons.local_cafe,
                color: Colors.orange,
                isDarkMode: isDarkMode,
                onTap: () => _showDonationDialog(context),
              ),
              const SizedBox(height: 12),
              _ActionButton(
                label: 'Sadist? Watch Ads Here 😈',
                icon: Icons.favorite,
                color: Colors.red,
                isDarkMode: isDarkMode,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const AdPage()),
                  );
                },
              ),
              const SizedBox(height: 12),
              _ActionButton(
                label: 'Feedback & Report Bugs',
                icon: Icons.message,
                color: Colors.blue,
                isDarkMode: isDarkMode,
                onTap: () {
                  if (mounted) {
                    showDialog(
                      context: context,
                      builder: (context) => const FeedbackFormDialog(),
                    );
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Social Links
        _SectionCard(
          title: 'Connect',
          isDarkMode: isDarkMode,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: const [
              _SocialIcon(icon: Icons.language, label: 'Website'),
              _SocialIcon(icon: Icons.facebook, label: 'Facebook'),
              _SocialIcon(icon: Icons.email_rounded, label: 'Email'),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Footer
        _Footer(),
        const SizedBox(height: 32),
      ],
    );
  }
}

/// Extracted section card widget to improve performance
class _SectionCard extends StatelessWidget {
  final String title;
  final bool isDarkMode;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.isDarkMode,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
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
}

/// Action button widget - extracted for reusability and performance
class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isDarkMode;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.isDarkMode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
}

/// Social icon widget - extracted and made constant where possible
class _SocialIcon extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SocialIcon({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

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

/// Footer widget - extracted for separation of concerns
class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: Text(
            'Thank you for supporting Keto!',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            '© 2025 Keto. All rights reserved.',
            style: TextStyle(
              fontSize: 12,
              color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'v${LocalizationService.appVersion}',
            style: TextStyle(
              fontSize: 10,
              color: isDarkMode ? Colors.grey[600] : Colors.grey[500],
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }
}

/// Donation option widget for the dialog
class _DonationOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isDarkMode;
  final VoidCallback onTap;

  const _DonationOption({
    required this.label,
    required this.icon,
    required this.color,
    required this.isDarkMode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.grey[200] : Colors.grey[800],
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward,
                color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// About feature widget with icon and description
class _AboutFeature extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool isDarkMode;

  const _AboutFeature({
    required this.icon,
    required this.title,
    required this.description,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.blue.withValues(alpha: 0.8),
                Colors.blue.withValues(alpha: 0.6),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.grey[900],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
