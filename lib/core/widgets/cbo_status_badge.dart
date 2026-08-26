import 'package:flutter/material.dart';
import '../constants/cbo_colors.dart';

enum ReconStatusType { ok, mismatch, missing, info, warning }

class CboStatusBadge extends StatelessWidget {
  final String label;
  final ReconStatusType type;

  const CboStatusBadge({
    super.key,
    required this.label,
    this.type = ReconStatusType.info,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;

    switch (type) {
      case ReconStatusType.ok:
        bg = CboColors.statusOkBg;
        fg = CboColors.statusOkText;
        break;
      case ReconStatusType.mismatch:
        bg = CboColors.statusMismatchBg;
        fg = CboColors.statusMismatchText;
        break;
      case ReconStatusType.missing:
        bg = CboColors.statusMissingBg;
        fg = CboColors.statusMissingText;
        break;
      case ReconStatusType.warning:
        bg = CboColors.accentGoldLight;
        fg = const Color(0xFFB78103);
        break;
      case ReconStatusType.info:
        bg = CboColors.primaryCyanUltraLight;
        fg = CboColors.primaryCyanDark;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w700,
          fontSize: 11,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
