import 'package:flutter/material.dart';

/// Placeholder for destinations that are planned but not built yet, so the
/// navigation can be wired end to end before each screen exists.
class ComingSoonScreen extends StatelessWidget {
  final String title;
  final String? description;

  const ComingSoonScreen({super.key, required this.title, this.description});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.construction,
                size: 48,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text('Coming soon', style: Theme.of(context).textTheme.titleLarge),
              if (description != null) ...[
                const SizedBox(height: 8),
                Text(
                  description!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
