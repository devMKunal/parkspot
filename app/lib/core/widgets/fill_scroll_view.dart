import 'package:flutter/widgets.dart';

/// Scrolls on short screens, fills the screen on tall ones, so a [Spacer]
/// in [child] still pushes the buttons to the bottom.
class FillScrollView extends StatelessWidget {
  const FillScrollView({
    required this.child,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  /// A Column, usually with a Spacer above its buttons.
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: padding,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: (constraints.maxHeight - padding.vertical).clamp(
              0,
              double.infinity,
            ),
          ),
          child: IntrinsicHeight(child: child),
        ),
      ),
    );
  }
}
