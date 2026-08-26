import 'package:flutter/material.dart';
import '../constants/cbo_colors.dart';

class CboFileDropzone extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? selectedFileName;
  final String? fileName;
  final int? rowCount;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  final Color activeColor;

  const CboFileDropzone({
    super.key,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.selectedFileName,
    this.fileName,
    this.rowCount,
    this.icon = Icons.upload_file_rounded,
    this.onClear,
    this.activeColor = CboColors.primaryCyan,
  });

  @override
  Widget build(BuildContext context) {
    final String? effectiveFileName = fileName ?? selectedFileName;
    final bool isLoaded = effectiveFileName != null && effectiveFileName.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: isLoaded ? activeColor.withValues(alpha: 0.04) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLoaded ? activeColor : CboColors.cardBorder,
          width: isLoaded ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isLoaded ? activeColor : CboColors.slateUltraLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isLoaded ? Icons.check_circle_rounded : icon,
                    color: isLoaded ? Colors.white : CboColors.slateMedium,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: isLoaded ? activeColor : CboColors.slateDark,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (isLoaded)
                        Text(
                          '$effectiveFileName ${rowCount != null ? "($rowCount rows)" : ""}',
                          style: const TextStyle(
                            color: CboColors.slateMedium,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      else if (subtitle != null)
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            color: CboColors.slateMuted,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                if (isLoaded && onClear != null)
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18, color: CboColors.slateMuted),
                    onPressed: onClear,
                    tooltip: 'Clear file',
                  )
                else
                  const Icon(Icons.file_upload_outlined, size: 20, color: CboColors.slateMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
