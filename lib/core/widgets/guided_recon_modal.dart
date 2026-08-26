import 'package:flutter/material.dart';
import '../constants/cbo_colors.dart';

class ReconStepGuide {
  final int step;
  final String title;
  final String format;
  final String description;
  final List<String>? expectedColumns;

  const ReconStepGuide({
    required this.step,
    required this.title,
    required this.format,
    required this.description,
    this.expectedColumns,
  });
}

class GuidedReconModal extends StatelessWidget {
  final String moduleTitle;
  final String modulePurpose;
  final List<ReconStepGuide> steps;
  final List<String>? tips;

  const GuidedReconModal({
    super.key,
    required this.moduleTitle,
    required this.modulePurpose,
    required this.steps,
    this.tips,
  });

  static void show(
    BuildContext context, {
    required String moduleTitle,
    required String modulePurpose,
    required List<ReconStepGuide> steps,
    List<String>? tips,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => GuidedReconModal(
        moduleTitle: moduleTitle,
        modulePurpose: modulePurpose,
        steps: steps,
        tips: tips,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: CboColors.primaryCyanUltraLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.auto_stories_rounded, color: CboColors.primaryCyan, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          moduleTitle,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: CboColors.slateDark,
                          ),
                        ),
                        const Text(
                          'Operational Execution Workflow Guide',
                          style: TextStyle(
                            fontSize: 12,
                            color: CboColors.slateMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: CboColors.slateMuted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Purpose Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: CboColors.slateUltraLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: CboColors.cardBorder),
                ),
                child: Text(
                  modulePurpose,
                  style: const TextStyle(
                    fontSize: 13,
                    color: CboColors.slateMedium,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Required File Ingestion Steps',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: CboColors.slateDark,
                ),
              ),
              const SizedBox(height: 10),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: steps.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final s = steps[i];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: CboColors.cardBorder),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: CboColors.primaryCyan,
                            child: Text(
                              '${s.step}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      s.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: CboColors.slateDark,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: CboColors.primaryCyanUltraLight,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        s.format,
                                        style: const TextStyle(
                                          color: CboColors.primaryCyanDark,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  s.description,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: CboColors.slateMedium,
                                  ),
                                ),
                                if (s.expectedColumns != null && s.expectedColumns!.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 4,
                                    runSpacing: 4,
                                    children: s.expectedColumns!.map((col) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: CboColors.slateUltraLight,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          col,
                                          style: const TextStyle(
                                            fontFamily: 'Consolas',
                                            fontSize: 10,
                                            color: CboColors.slateDark,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              if (tips != null && tips!.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: CboColors.accentGoldLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: CboColors.accentGold.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lightbulb_rounded, color: CboColors.accentGold, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          tips!.join(' • '),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF78350F),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Got It, Proceed'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
