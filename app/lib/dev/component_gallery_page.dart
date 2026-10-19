import 'package:flutter/material.dart';
import 'package:parkspot/core/extensions/context_x.dart';
import 'package:parkspot/core/theme/app_spacing.dart';
import 'package:parkspot/core/theme/app_theme.dart';
import 'package:parkspot/core/theme/app_typography.dart';
import 'package:parkspot/core/utils/availability.dart';
import 'package:parkspot/core/utils/formatters.dart';
import 'package:parkspot/core/utils/money.dart';
import 'package:parkspot/core/widgets/alert_banner.dart';
import 'package:parkspot/core/widgets/app_text_field.dart';
import 'package:parkspot/core/widgets/availability_badge.dart';
import 'package:parkspot/core/widgets/brand_mark.dart';
import 'package:parkspot/core/widgets/choice_pill.dart';
import 'package:parkspot/core/widgets/chunky_button.dart';
import 'package:parkspot/core/widgets/countdown_ring.dart';
import 'package:parkspot/core/widgets/duration_preset_card.dart';
import 'package:parkspot/core/widgets/lot_marker.dart';
import 'package:parkspot/core/widgets/page_dots.dart';
import 'package:parkspot/core/widgets/stat_tile.dart';
import 'package:parkspot/core/widgets/status_chip.dart';
import 'package:parkspot/core/widgets/ticket_card.dart';

/// Every shared widget in one scrolling page, to compare against the
/// mockups in light and dark. Dev-only: remove the route before release.
class ComponentGalleryPage extends StatefulWidget {
  const ComponentGalleryPage({super.key});

  @override
  State<ComponentGalleryPage> createState() => _ComponentGalleryPageState();
}

class _ComponentGalleryPageState extends State<ComponentGalleryPage> {
  bool? _dark;
  int _day = 0;
  int _slot = 0;
  int _preset = 2;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final dark = _dark ?? context.isDark;
    return Theme(
      data: dark ? AppTheme.dark() : AppTheme.light(),
      child: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Components'),
            actions: [
              IconButton(
                tooltip: dark ? 'Light theme' : 'Dark theme',
                icon: Icon(
                  dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                ),
                onPressed: () => setState(() => _dark = !dark),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.sm,
              AppSpacing.xl,
              AppSpacing.xxxl,
            ),
            children: [
              const _Section('Brand and type'),
              Row(
                children: [
                  const BrandMark(),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Text(
                      'Where are we parking?',
                      style: context.text.headlineSmall,
                    ),
                  ),
                ],
              ),
              const _Section('Chunky buttons'),
              ChunkyButton(
                label: 'Grab a spot',
                trailingIcon: Icons.arrow_forward_rounded,
                onPressed: () {},
              ),
              const SizedBox(height: AppSpacing.md),
              ChunkyButton(
                label: 'Need more time?',
                variant: ChunkyButtonVariant.accent,
                onPressed: () {},
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  ChunkyButton.icon(
                    icon: Icons.near_me_rounded,
                    semanticLabel: 'Directions',
                    onPressed: () {},
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: ChunkyButton(
                      label: 'Pay ${Formatters.money(const Money(8000))}',
                      loading: _loading,
                      onPressed: () => setState(() => _loading = !_loading),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              const ChunkyButton(label: 'Disabled', onPressed: null),
              const _Section('Fields and alerts'),
              const AlertBanner(
                message:
                    "That email and password don't match. Check them and "
                    'try again.',
              ),
              const SizedBox(height: AppSpacing.md),
              const AlertBanner(
                tone: AlertTone.warning,
                message: 'Slot B-14 is held for you until 6:40 PM.',
              ),
              const SizedBox(height: AppSpacing.lg),
              const AppTextField(
                label: 'Email',
                hintText: 'you@example.com',
                keyboardType: TextInputType.emailAddress,
                autofillHints: [AutofillHints.email],
              ),
              const SizedBox(height: AppSpacing.md),
              const AppTextField(
                label: 'Password',
                obscure: true,
                helperText: '8+ characters',
                autofillHints: [AutofillHints.newPassword],
              ),
              const SizedBox(height: AppSpacing.md),
              const AppTextField(
                label: 'Confirm password',
                obscure: true,
                errorText: "Passwords don't match",
              ),
              const _Section('Pills and presets'),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  for (final (i, d) in [
                    'Today',
                    'Tomorrow',
                    'Pick a date',
                  ].indexed)
                    ChoicePill(
                      label: d,
                      selected: _day == i,
                      onSelected: () => setState(() => _day = i),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: AppSpacing.sm,
                childAspectRatio: 1.5,
                children: [
                  for (final (i, t) in [
                    '6:30 PM',
                    '6:45 PM',
                    '7:00 PM',
                    '7:15 PM',
                  ].indexed)
                    ChoicePill(
                      label: t,
                      height: 48,
                      emphasis: ChoicePillEmphasis.primary,
                      selected: _slot == i,
                      onSelected: () => setState(() => _slot = i),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              // Rows, not a fixed-aspect grid: cards grow with the text scale.
              for (final row in [0, 2]) ...[
                Row(
                  children: [
                    for (final i in [row, row + 1]) ...[
                      if (i.isOdd) const SizedBox(width: AppSpacing.sm + 2),
                      Expanded(
                        child: DurationPresetCard(
                          title: _presets[i].$1,
                          value: Formatters.duration(_presets[i].$2),
                          selected: _preset == i,
                          onTap: () => setState(() => _preset = i),
                        ),
                      ),
                    ],
                  ],
                ),
                if (row == 0) const SizedBox(height: AppSpacing.sm + 2),
              ],
              const _Section('Lot facts'),
              const Row(
                children: [
                  AvailabilityBadge(level: Availability.high),
                  SizedBox(width: AppSpacing.sm),
                  AvailabilityBadge(level: Availability.medium),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              const Row(
                children: [
                  AvailabilityBadge(level: Availability.low),
                  SizedBox(width: AppSpacing.sm),
                  AvailabilityBadge(level: Availability.full),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      label: 'Price',
                      value: Formatters.money(const Money(4000)),
                      unit: '/hr',
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm + 2),
                  Expanded(
                    child: StatTile(
                      label: 'Away',
                      value: Formatters.distance(412),
                      tint: StatTileTint.yellow,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm + 2),
                  const Expanded(
                    child: StatTile(
                      label: 'Free',
                      value: '37',
                      unit: '/120',
                      tint: StatTileTint.mint,
                    ),
                  ),
                ],
              ),
              const _Section('Map markers'),
              Container(
                height: 120,
                decoration: BoxDecoration(
                  color: context.colors.surfaceContainer,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(bottom: 24),
                      child: LotMarker(
                        freeSlots: 37,
                        totalSlots: 120,
                        selected: true,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(bottom: 24),
                      child: LotMarker(freeSlots: 6, totalSlots: 40),
                    ),
                    Padding(
                      padding: EdgeInsets.only(bottom: 24),
                      child: LotMarker(freeSlots: 0, totalSlots: 25),
                    ),
                  ],
                ),
              ),
              const _Section('Tickets and status'),
              TicketCard(
                color: context.semantic.tintYellow,
                child: Column(
                  children: [
                    _row(context, '₹40 × 2 h · 6:30 to 8:30 PM', '₹80'),
                    const SizedBox(height: AppSpacing.md),
                    DashedDivider(color: context.semantic.accentDeep),
                    const SizedBox(height: AppSpacing.md),
                    _row(context, 'Total', '₹80', loud: true),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  StatusChip(
                    label: 'Checked in',
                    tone: StatusTone.success,
                    icon: Icons.check_rounded,
                  ),
                  StatusChip(
                    label: 'Happening now',
                    tone: StatusTone.highlight,
                  ),
                  StatusChip(label: 'Cancelled · refunded'),
                  StatusChip(label: 'Not paid', tone: StatusTone.danger),
                ],
              ),
              const _Section('Countdown and onboarding'),
              Row(
                children: [
                  CountdownRing(
                    remaining: 0.85,
                    semanticLabel: '1 hour 42 minutes left',
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '1:42',
                          style: context.text.headlineMedium?.copyWith(
                            fontFeatures: AppTypography.tabular,
                          ),
                        ),
                        Text(
                          'left',
                          style: context.text.labelMedium?.copyWith(
                            color: context.colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xxl),
                  const PageDots(count: 3, index: 1),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const _presets = [
    ('Quick errand', Duration(minutes: 30)),
    ('Coffee & catch-up', Duration(hours: 1)),
    ('Shopping spree', Duration(hours: 2)),
    ('Movie night', Duration(hours: 3)),
  ];

  Widget _row(BuildContext context, String a, String b, {bool loud = false}) {
    final style = loud
        ? context.text.headlineSmall
        : context.text.bodyMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Flexible(
          child: Text(a, style: loud ? context.text.titleMedium : style),
        ),
        Text(b, style: style),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.xxl,
        bottom: AppSpacing.md,
      ),
      child: Text(
        title,
        style: context.text.titleMedium?.copyWith(
          color: context.colors.onSurfaceVariant,
        ),
      ),
    );
  }
}
