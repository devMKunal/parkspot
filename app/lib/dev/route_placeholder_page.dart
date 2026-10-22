import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:parkspot/core/extensions/context_x.dart';
import 'package:parkspot/core/theme/app_spacing.dart';
import 'package:parkspot/core/widgets/brand_mark.dart';
import 'package:parkspot/core/widgets/chunky_button.dart';
import 'package:parkspot/dev/dev_session.dart';
import 'package:parkspot/router/app_routes.dart';

enum StubAuthAction { signIn, signOut, completeOnboarding }

/// A button on a placeholder: go somewhere, or poke the [DevSession].
class PlaceholderAction {
  const PlaceholderAction.go(this.label, String this.location) : stub = null;

  /// Runs [stub], then goes to [then] if given. Signing in or out needs no
  /// [then]: the redirect moves the user.
  const PlaceholderAction.stub(
    this.label,
    StubAuthAction this.stub, {
    String? then,
  }) : location = then;

  final String label;
  final String? location;
  final StubAuthAction? stub;
}

/// Temporary screen for a route whose real page isn't built yet. It shows
/// the path and links onward, so the whole flow can be clicked through.
class RoutePlaceholderPage extends StatelessWidget {
  const RoutePlaceholderPage({
    required this.title,
    this.note = 'Placeholder: the real screen replaces this.',
    this.actions = const [],
    super.key,
  });

  final String title;
  final String note;
  final List<PlaceholderAction> actions;

  void _run(BuildContext context, PlaceholderAction action) {
    final session = DevSessionScope.maybeOf(context);
    switch (action.stub) {
      case StubAuthAction.signIn:
        session?.signIn();
      case StubAuthAction.signOut:
        session?.signOut();
      case StubAuthAction.completeOnboarding:
        session?.completeOnboarding();
      case null:
        break;
    }
    final location = action.location;
    if (location == null) return;
    // Keep a pending deep link alive through onboarding, sign-up and login.
    final from = GoRouterState.of(
      context,
    ).uri.queryParameters[AppRoutes.fromParam];
    context.go(
      AppRoutes.isEntry(location)
          ? AppRoutes.withFrom(location, from)
          : location,
    );
  }

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            const Align(child: BrandMark(size: 48)),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              style: context.text.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '$note\n$path',
              style: context.text.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            for (final (i, action) in actions.indexed) ...[
              const SizedBox(height: AppSpacing.md),
              ChunkyButton(
                label: action.label,
                variant: i == 0
                    ? ChunkyButtonVariant.primary
                    : ChunkyButtonVariant.outline,
                onPressed: () => _run(context, action),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
