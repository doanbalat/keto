import 'package:url_launcher/url_launcher.dart';

class EmailService {
  // Your email address
  static const String _recipientEmail = 'doanbalat1995@gmail.com';
  
  /// Opens the default email client with a pre-filled feedback form
  static Future<void> sendFeedbackEmail({
    required String subject,
    required String body,
    required String userEmail,
  }) async {
    // Manually build the mailto URL with proper encoding
    final encodedSubject = Uri.encodeComponent(subject);
    final encodedBody = Uri.encodeComponent(body);
    final encodedReplyTo = Uri.encodeComponent(userEmail);
    final mailtoUrl = 'mailto:$_recipientEmail?subject=$encodedSubject&body=$encodedBody&reply-to=$encodedReplyTo';
    
    try {
      if (await canLaunchUrl(Uri.parse(mailtoUrl))) {
        await launchUrl(
          Uri.parse(mailtoUrl),
          mode: LaunchMode.externalApplication,
        );
      } else {
        throw 'Could not launch email client';
      }
    } catch (e) {
      throw 'Error opening email: $e';
    }
  }
}
