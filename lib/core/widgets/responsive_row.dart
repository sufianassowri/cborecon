import 'package:flutter/material.dart';

/// A widget that displays its children in a Row on large screens (with Expanded flex factors)
/// and stacks them in a Column on smaller screens.
class ResponsiveRow extends StatelessWidget {
  final List<Widget> children;
  final List<int>? flexes;
  final double breakpoint;
  final double spacing;
  final CrossAxisAlignment crossAxisAlignment;

  const ResponsiveRow({
    super.key,
    required this.children,
    this.flexes,
    this.breakpoint = 900,
    this.spacing = 16.0,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= breakpoint;
        
        if (!isDesktop) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1) SizedBox(height: spacing),
              ]
            ],
          );
        }

        return Row(
          crossAxisAlignment: crossAxisAlignment,
          children: [
            for (int i = 0; i < children.length; i++) ...[
              if (flexes != null && i < flexes!.length)
                Expanded(flex: flexes![i], child: children[i])
              else
                Expanded(child: children[i]),
              if (i != children.length - 1) SizedBox(width: spacing),
            ]
          ],
        );
      },
    );
  }
}
