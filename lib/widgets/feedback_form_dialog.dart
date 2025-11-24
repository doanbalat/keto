import 'package:flutter/material.dart';
import '../services/email_service.dart';

class FeedbackFormDialog extends StatefulWidget {
  const FeedbackFormDialog({super.key});

  @override
  State<FeedbackFormDialog> createState() => _FeedbackFormDialogState();
}

class _FeedbackFormDialogState extends State<FeedbackFormDialog> {
  static const String _feedbackSubject = 'Feedback/Report';
  
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final body = 'Name: ${_nameController.text}\n'
          '\n'
          'Message:\n'
          '${_messageController.text}';

      await EmailService.sendFeedbackEmail(
        subject: _feedbackSubject,
        body: body,
        userEmail: _emailController.text,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email client opened! Please send your feedback.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
                ),
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Name is required';
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
                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value!)) {
                    return 'Enter a valid email';
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
                ),
                maxLines: 5,
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Message is required';
                  }
                  if (value!.length < 10) {
                    return 'Message must be at least 10 characters';
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
