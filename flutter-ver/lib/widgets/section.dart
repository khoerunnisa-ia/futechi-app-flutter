import 'package:flutter/material.dart';

import 'page_title.dart';

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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: FutechiColors.foreground)),
            ),
            if (action != null) action!,
          ],
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }
}
