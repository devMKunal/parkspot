import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:parkspot/core/extensions/context_x.dart';
import 'package:parkspot/core/theme/app_spacing.dart';
import 'package:parkspot/core/utils/formatters.dart';
import 'package:parkspot/core/widgets/alert_banner.dart';
import 'package:parkspot/core/widgets/availability_badge.dart';
import 'package:parkspot/core/widgets/chunky_button.dart';
import 'package:parkspot/core/widgets/stat_tile.dart';
import 'package:parkspot/features/lots/domain/lot.dart';
import 'package:parkspot/features/map/presentation/bloc/map_bloc.dart';

/// The bottom sheet: the open lot, or why there isn't one.
class LotSheet extends StatelessWidget {
  const LotSheet({required this.onBook, required this.onDirections, super.key});

  final ValueChanged<Lot> onBook;
  final ValueChanged<Lot> onDirections;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      container: true,
      label: 'Lot details',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.sm + 2,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLowest,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheet),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x24000000),
              blurRadius: 24,
              offset: Offset(0, -6),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: colors.outlineVariant,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              BlocBuilder<MapBloc, MapState>(
                builder: (context, state) {
                  final lot = state.selected;
                  if (lot != null) {
                    return _LotDetails(
                      lot: lot,
                      distance: state.distanceTo(lot),
                      onBook: () => onBook(lot),
                      onDirections: () => onDirections(lot),
                    );
                  }
                  return _Empty(state: state);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LotDetails extends StatelessWidget {
  const _LotDetails({
    required this.lot,
    required this.distance,
    required this.onBook,
    required this.onDirections,
  });

  final Lot lot;
  final int? distance;
  final VoidCallback onBook;
  final VoidCallback onDirections;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: AvailabilityBadge(level: lot.availability),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(lot.name, style: context.text.headlineSmall),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          lot.address,
          style: context.text.bodyMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: 'Price',
                value: Formatters.money(lot.pricePerHour),
                unit: '/hr',
              ),
            ),
            const SizedBox(width: AppSpacing.sm + 2),
            Expanded(
              child: StatTile(
                label: 'Away',
                value: distance == null ? '–' : Formatters.distance(distance!),
                tint: StatTileTint.yellow,
              ),
            ),
            const SizedBox(width: AppSpacing.sm + 2),
            Expanded(
              child: StatTile(
                label: 'Free',
                value: '${lot.freeSlots}',
                unit: '/${lot.totalSlots}',
                tint: StatTileTint.mint,
              ),
            ),
          ],
        ),
        if (lot.photos.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 64,
            child: Row(
              children: [
                for (final (i, url) in lot.photos.take(3).indexed) ...[
                  if (i > 0) const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        url,
                        fit: BoxFit.cover,
                        semanticLabel: 'Photo of ${lot.name}',
                        errorBuilder: (context, _, _) =>
                            ColoredBox(color: context.colors.surfaceContainer),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ChunkyButton.icon(
              icon: Icons.near_me_rounded,
              semanticLabel: 'Directions',
              onPressed: onDirections,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: ChunkyButton(
                label: lot.isFull ? 'Lot is full' : 'Grab a spot',
                trailingIcon: lot.isFull ? null : Icons.arrow_forward_rounded,
                onPressed: lot.isFull ? null : onBook,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.state});

  final MapState state;

  @override
  Widget build(BuildContext context) {
    final muted = context.text.bodyMedium?.copyWith(
      color: context.colors.onSurfaceVariant,
    );
    if (state.status == MapStatus.failure) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AlertBanner(message: state.error ?? "Couldn't load lots."),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: () => context.read<MapBloc>().add(const MapRetried()),
            child: const Text('Try again'),
          ),
        ],
      );
    }
    if (state.status == MapStatus.loading && state.lots.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(width: AppSpacing.md),
            Text('Looking for lots near you…', style: muted),
          ],
        ),
      );
    }
    final query = state.query.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Text(
        query.isEmpty
            ? 'No lots around here. Move the map to look further.'
            : 'No lots match "$query" here. Try another name or move the map.',
        textAlign: TextAlign.center,
        style: muted,
      ),
    );
  }
}
