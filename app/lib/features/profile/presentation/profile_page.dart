import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:parkspot/core/di/injector.dart';
import 'package:parkspot/core/extensions/context_x.dart';
import 'package:parkspot/core/theme/app_spacing.dart';
import 'package:parkspot/core/theme/theme_mode_controller.dart';
import 'package:parkspot/core/widgets/brand_mark.dart';
import 'package:parkspot/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:parkspot/router/app_routes.dart';

/// Who's signed in, My trips, Appearance and Log out. No bloc: the user
/// comes from AuthBloc and the theme from [ThemeModeController].
class ProfilePage extends StatelessWidget {
  const ProfilePage({this.themeMode, super.key});

  /// Defaults to the app's; tests pass their own.
  final ThemeModeController? themeMode;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final user = context.select<AuthBloc, String?>((b) => b.state.user?.name);
    final email = context.select<AuthBloc, String?>((b) => b.state.user?.email);
    final theme = themeMode ?? getIt<ThemeModeController>();
    final onCard = colors.onPrimary;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back to the map',
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(AppRoutes.home),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg + 2),
            decoration: BoxDecoration(
              color: colors.primary,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: [
                BoxShadow(
                  color: context.semantic.primaryDeep,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                BrandMark(
                  size: 68,
                  child: Text(
                    (user?.trim().characters.firstOrNull ?? 'P').toUpperCase(),
                    style: context.text.headlineMedium?.copyWith(
                      color: context.semantic.onAccent,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user ?? '',
                        style: context.text.headlineSmall?.copyWith(
                          color: onCard,
                        ),
                      ),
                      Text(
                        email ?? '',
                        style: context.text.bodyMedium?.copyWith(
                          color: onCard.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg + 2),
          // Material, not a DecoratedBox: the ListTile's ink needs one.
          Material(
            color: colors.surfaceContainerLowest,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: BorderSide(color: colors.outlineVariant, width: 2),
            ),
            child: Column(
              children: [
                ListTile(
                  minTileHeight: 60,
                  leading: _IconTile(
                    icon: Icons.receipt_long_rounded,
                    color: context.semantic.tintViolet,
                  ),
                  title: const Text('My trips'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.go(AppRoutes.trips),
                ),
                Divider(height: 2, thickness: 2, color: colors.outlineVariant),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          _IconTile(
                            icon: Icons.light_mode_rounded,
                            color: context.semantic.tintYellow,
                          ),
                          const SizedBox(width: AppSpacing.md + 2),
                          Text('Appearance', style: context.text.titleSmall),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm + 2),
                      ValueListenableBuilder(
                        valueListenable: theme,
                        builder: (context, mode, _) => SegmentedButton(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(
                              value: ThemeMode.system,
                              label: Text('System'),
                            ),
                            ButtonSegment(
                              value: ThemeMode.light,
                              label: Text('Light'),
                            ),
                            ButtonSegment(
                              value: ThemeMode.dark,
                              label: Text('Dark'),
                            ),
                          ],
                          selected: {mode},
                          onSelectionChanged: (picked) =>
                              theme.select(picked.single),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxxl),
          SizedBox(
            height: 56,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.error,
                side: BorderSide(color: colors.outlineVariant, width: 2),
              ),
              onPressed: () =>
                  context.read<AuthBloc>().add(const AuthLogoutRequested()),
              child: const Text('Log out'),
            ),
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          Center(
            child: Text(
              'Made in Pune',
              style: context.text.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 18, color: context.colors.primary),
      ),
    );
  }
}
