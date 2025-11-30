import 'package:flutter/material.dart';
import '../services/email_service.dart';

class FeedbackFormDialog extends StatefulWidget {
  const FeedbackFormDialog({super.key});

  @override
  State<FeedbackFormDialog> createState() => _FeedbackFormDialogState();
}

class _FeedbackFormDialogState extends State<FeedbackFormDialog> {
  static const String _feedbackSubject = 'Keto App Feedback/Report';
  static const int _minMessageLength = 10;
  static const int _maxNameLength = 100;
  static const int _maxMessageLength = 2000;
  
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isLoading = false;
  
  /// Validates email format using a simplified pattern
  bool _isValidEmail(String email) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email);
  }
  
  /// Sanitizes user input by trimming and removing extra whitespace
  String _sanitizeInput(String input) {
    return input.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    // Validate form
    if (!_formKey.currentState!.validate()) return;

    // Check if widget is still mounted
    if (!mounted) return;

    // Disable submit while processing
    setState(() => _isLoading = true);

    try {
      // Sanitize inputs
      final name = _sanitizeInput(_nameController.text);
      final email = _sanitizeInput(_emailController.text);
      final message = _sanitizeInput(_messageController.text);

      // Double-check validation before sending
      if (name.isEmpty || email.isEmpty || message.isEmpty) {
        throw 'Invalid input data';
      }

      if (!_isValidEmail(email)) {
        throw 'Invalid email format';
      }

      if (message.length < _minMessageLength) {
        throw 'Message is too short';
      }

      // Build email body
      final body = 'Name: $name\n\nMessage:\n$message';

      // Send feedback through email service
      await EmailService.sendFeedbackEmail(
        subject: _feedbackSubject,
        body: body,
        userEmail: email,
      );

      // Check mounted again before showing dialogs
      if (!mounted) return;

      // Close dialog
      Navigator.pop(context);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email client opened! Please send your feedback.'),
          duration: Duration(seconds: 3),
        ),
      );
    } on Exception catch (e) {
      // Check mounted before showing error
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      // Check mounted before updating state
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      title: const Text('Send Feedback'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Your Name',
                  hintText: 'Enter your name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor:
                      isDarkMode ? Colors.grey[800] : Colors.grey[100],
                  counterText: '${_nameController.text.length}/$_maxNameLength',
                ),
                maxLength: _maxNameLength,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => setState(() {}),
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Name is required';
                  }
                  final trimmed = value!.trim();
                  if (trimmed.length < 2) {
                    return 'Name must be at least 2 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Your Email',
                  hintText: 'your@email.com',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor:
                      isDarkMode ? Colors.grey[800] : Colors.grey[100],
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Email is required';
                  }
                  final trimmed = value!.trim();
                  if (!_isValidEmail(trimmed)) {
                    return 'Enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _messageController,
                decoration: InputDecoration(
                  labelText: 'Message',
                  hintText: 'Your feedback or bug report...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor:
                      isDarkMode ? Colors.grey[800] : Colors.grey[100],
                  alignLabelWithHint: true,
                  counterText: '${_messageController.text.length}/$_maxMessageLength',
                ),
                maxLines: 5,
                maxLength: _maxMessageLength,
                onChanged: (_) => setState(() {}),
                textCapitalization: TextCapitalization.sentences,
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Message is required';
                  }
                  final trimmed = value!.trim();
                  if (trimmed.length < _minMessageLength) {
                    return 'Message must be at least $_minMessageLength characters';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitFeedback,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Send Feedback'),
        ),
      ],
    );
  }
}
