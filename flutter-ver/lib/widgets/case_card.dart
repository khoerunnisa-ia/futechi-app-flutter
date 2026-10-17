import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../data/health_case.dart';

/// Rounded card container matching the `card` Tailwind class.
class FutechiCard extends StatelessWidget {
  const FutechiCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: FutechiColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: borderColor ?? FutechiColors.border,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12243024),
            blurRadius: 28,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
    if (onTap == null) return card;
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(20), child: card);
  }
}

/// Port of StatusBadge.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final CaseStatus status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      CaseStatus.sick => (FutechiColors.dangerSoft, FutechiColors.danger),
      CaseStatus.healthy => (FutechiColors.successSoft, FutechiColors.success),
      CaseStatus.pending => (FutechiColors.warningSoft, FutechiColors.warning),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(
        caseStatusLabel(status),
        style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

/// Port of CaseCard (two variants: compact list row and image-top card).
class CaseCard extends StatelessWidget {
  const CaseCard({
    super.key,
    required this.healthCase,
    required this.status,
    this.imageTop = false,
  });

  final HealthCase healthCase;
  final CaseStatus status;
  final bool imageTop;

  @override
  Widget build(BuildContext context) {
    if (imageTop) return _ImageTopCaseCard(healthCase: healthCase, status: status);
    return _CompactCaseCard(healthCase: healthCase, status: status);
  }
}

class _CompactCaseCard extends StatelessWidget {
  const _CompactCaseCard({required this.healthCase, required this.status});

  final HealthCase healthCase;
  final CaseStatus status;

  @override
  Widget build(BuildContext context) {
    final isCritical = healthCase.level == CaseLevel.kritis;
    final accent = isCritical ? FutechiColors.danger : FutechiColors.warning;
    return FutechiCard(
      padding: EdgeInsets.zero,
      onTap: () => _open(context, healthCase),
      borderColor: accent,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: caseImage(healthCase.image, width: 80, height: 80, fit: BoxFit.cover),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(healthCase.chickenId,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(
                    '${healthCase.topPossibility.name} · Confidence ${healthCase.topPossibility.confidence}%',
                    style: const TextStyle(
                        fontSize: 13, color: FutechiColors.mutedForeground),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 10,
                    children: [
                      Text(
                        'Terdeteksi pada: ${healthCase.date}, ${healthCase.time}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      StatusBadge(status: status),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              healthCase.level.name == 'kritis' ? 'Kritis' : 'Peringatan',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: accent),
            ),
            const Icon(Icons.chevron_right, size: 16, color: FutechiColors.mutedForeground),
          ],
        ),
      ),
    );
  }
}

class _ImageTopCaseCard extends StatelessWidget {
  const _ImageTopCaseCard({required this.healthCase, required this.status});

  final HealthCase healthCase;
  final CaseStatus status;

  @override
  Widget build(BuildContext context) {
    final isCritical = healthCase.level == CaseLevel.kritis;
    final accent = isCritical ? FutechiColors.danger : FutechiColors.warning;
    return FutechiCard(
      padding: EdgeInsets.zero,
      onTap: () => _open(context, healthCase),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: caseImage(healthCase.image, fit: BoxFit.cover),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(healthCase.topPossibility.name,
                              style: const TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(
                            '${healthCase.date}, ${healthCase.time}',
                            style: const TextStyle(
                                fontSize: 12, color: FutechiColors.mutedForeground),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: accent),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        healthCase.level.name == 'kritis' ? 'Kritis' : 'Peringatan',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700, color: accent),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.only(top: 12),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: FutechiColors.border)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(healthCase.chickenId,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            Text(healthCase.cage,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12, color: FutechiColors.mutedForeground)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      StatusBadge(status: status),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

void _open(BuildContext context, HealthCase healthCase) {
  Navigator.of(context).pushNamed(
    '/history/consultation',
    arguments: healthCase.id,
  );
}

/// Image resolution for case thumbnails.
/// Every [CaseImage] variant maps to a bundled local asset; the switch is
/// exhaustive, so no fallback branch is needed.
Widget caseImage(CaseImage image,
    {double? width, double? height, BoxFit fit = BoxFit.cover}) {
  final asset = switch (image) {
    CaseImage.sick => 'assets/images/sick-chicken-feeding.jpg',
    CaseImage.avian => 'assets/images/avian-influenza.jpg',
    CaseImage.morning => 'assets/images/chickens-feeding-morning.jpg',
    CaseImage.evening => 'assets/images/chickens-feeding-evening.jpg',
  };
  return Image.asset(asset, width: width, height: height, fit: fit);
}
