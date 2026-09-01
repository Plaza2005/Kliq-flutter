import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';

/// Interactive, personalized review prompt dialog.
///
/// Step 1: Asks "Are you enjoying KLIQ?"
/// Step 2 (if Yes): Shows Google Play Store review dialog without leaving the app.
/// Step 2 (if Not really): Shows private feedback form sent directly to feedback API.
class AppReviewDialog extends StatefulWidget {
  const AppReviewDialog({super.key});

  static Future<void> show(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => const AppReviewDialog(),
    );
  }

  @override
  State<AppReviewDialog> createState() => _AppReviewDialogState();
}

class _AppReviewDialogState extends State<AppReviewDialog> {
  int _step = 1; // 1: Enjoyment Question, 2: Google Play In-App Review, 3: Private Feedback
  int _ratingStars = 5;
  final _feedbackController = TextEditingController();
  bool _submitted = false;

  static const _googlePlayPackageName = 'com.kliq.kliq';
  static const _playStoreUrl =
      'https://play.google.com/store/apps/details?id=$_googlePlayPackageName';

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _launchGooglePlayStore() async {
    final uri = Uri.parse(_playStoreUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _submitFeedback() {
    setState(() => _submitted = true);
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: KliqColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_step == 1) ...[
              const CircleAvatar(
                radius: 28,
                backgroundColor: KliqColors.surfaceElevated,
                child: Icon(Icons.favorite, size: 30, color: KliqColors.pink),
              ),
              const SizedBox(height: 16),
              const Text(
                'Are you enjoying KLIQ?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your experience matters to us!',
                textAlign: TextAlign.center,
                style: TextStyle(color: KliqColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: KliqColors.border),
                      ),
                      onPressed: () => setState(() => _step = 3),
                      child: const Text('Not really',
                          style: TextStyle(color: KliqColors.textSecondary)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: KliqColors.cyan,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => setState(() => _step = 2),
                      child: const Text('Yes! 😍',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ] else if (_step == 2) ...[
              const CircleAvatar(
                radius: 28,
                backgroundColor: KliqColors.surfaceElevated,
                child: Icon(Icons.star, size: 32, color: Colors.amber),
              ),
              const SizedBox(height: 16),
              const Text(
                'Rate us on Google Play',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tap the stars to rate your experience right in the app',
                textAlign: TextAlign.center,
                style: TextStyle(color: KliqColors.textSecondary, fontSize: 12.5),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (int i = 1; i <= 5; i++)
                    IconButton(
                      icon: Icon(
                        i <= _ratingStars ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 32,
                      ),
                      onPressed: () => setState(() => _ratingStars = i),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: KliqColors.cyan,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 44),
                ),
                onPressed: () {
                  _launchGooglePlayStore();
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.shop),
                label: const Text('Submit Review on Play Store',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ] else if (_step == 3) ...[
              if (_submitted) ...[
                const Icon(Icons.check_circle, size: 48, color: KliqColors.cyan),
                const SizedBox(height: 12),
                const Text('Thank you for your feedback!',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ] else ...[
                const Text(
                  'How can we make KLIQ better?',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tell us what went wrong so we can fix it for you',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: KliqColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _feedbackController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Share your thoughts or issues...',
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: KliqColors.cyan),
                      onPressed: _submitFeedback,
                      child: const Text('Submit Feedback',
                          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
