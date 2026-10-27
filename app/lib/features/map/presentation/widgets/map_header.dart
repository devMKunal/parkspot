import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:parkspot/core/extensions/context_x.dart';
import 'package:parkspot/core/theme/app_spacing.dart';
import 'package:parkspot/core/widgets/choice_pill.dart';
import 'package:parkspot/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:parkspot/features/map/presentation/bloc/map_bloc.dart';

/// The floating card on top of the map: greeting, profile, search, sort.
class MapHeader extends StatelessWidget {
  const MapHeader({
    required this.searchFocus,
    required this.onProfile,
    super.key,
  });

  /// Focused after "Not now, I'll search" on the location rationale.
  final FocusNode searchFocus;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final name = context.select<AuthBloc, String?>((b) => b.state.user?.name);
    final firstName = name?.trim().split(' ').first;
    final sort = context.select<MapBloc, MapSort>((b) => b.state.sort);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(color: colors.outlineVariant, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (firstName != null && firstName.isNotEmpty)
                      Text(
                        'Hey $firstName',
                        style: context.text.labelLarge?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    Text(
                      'Where are we parking?',
                      style: context.text.headlineSmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              _Avatar(initial: firstName?.characters.first, onTap: onProfile),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // Screen readers get the purpose, not just the example.
          Semantics(
            label: 'Search area or parking lot',
            child: TextField(
              focusNode: searchFocus,
              textInputAction: TextInputAction.search,
              onChanged: (query) =>
                  context.read<MapBloc>().add(MapSearchChanged(query)),
              decoration: InputDecoration(
                hintText: 'FC Road, a mall, a café…',
                prefixIcon: Icon(Icons.search_rounded, color: colors.primary),
                filled: true,
                fillColor: colors.surfaceContainer,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final option in MapSort.values)
                ChoicePill(
                  label: option.label,
                  height: 36,
                  selected: option == sort,
                  onSelected: () =>
                      context.read<MapBloc>().add(MapSortChanged(option)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initial, required this.onTap});

  final String? initial;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    return Semantics(
      button: true,
      label: 'Profile',
      excludeSemantics: true,
      child: Material(
        color: semantic.accent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: SizedBox.square(
            dimension: AppSizes.minTouchTarget,
            child: Center(
              child: initial == null
                  ? Icon(Icons.person_rounded, color: semantic.onAccent)
                  : Text(
                      initial!.toUpperCase(),
                      style: context.text.titleMedium?.copyWith(
                        color: semantic.onAccent,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
