import 'package:flutter/material.dart';

import '../app/theme.dart';

export 'page_title.dart' show PageTitle;

/// Section heading used by History/Treatment/Dashboard screens.
class Section extends StatelessWidget {
  const Section({
    super.key,
    required this.title,
    required this.child,
    this.action,
  });

  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Text(title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(color: FutechiColors.foreground)),
              if (action != null) action!,
            ],
          ),
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }
}
