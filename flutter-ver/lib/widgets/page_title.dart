import 'package:flutter/material.dart';

import '../app/theme.dart';

/// Small page-level building blocks shared by screens.
class PageTitle extends StatelessWidget {
  const PageTitle({
    super.key,
    required this.title,
    required this.description,
    this.action,
  });

  final String title;
  final String description;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: FutechiColors.foreground)),
              const SizedBox(height: 4),
              Text(description,
                  style: const TextStyle(
                      fontSize: 14, color: FutechiColors.mutedForeground)),
            ],
          ),
        ),
        if (action != null) ...[const SizedBox(width: 16), action!],
      ],
    );
  }
}
