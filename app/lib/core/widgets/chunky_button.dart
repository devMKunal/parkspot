import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:parkspot/core/extensions/context_x.dart';
import 'package:parkspot/core/theme/app_spacing.dart';

enum ChunkyButtonVariant { primary, accent, outline }

/// The signature "pressable" button: a solid, unblurred bottom shadow that
/// the face sinks into on press, with a light haptic.
///
/// Use it for the one main action on a screen (Grab a spot, Pay, Show my
/// pass, Need more time). Everything else uses the themed Material buttons.
class ChunkyButton extends StatefulWidget {
  const ChunkyButton({
    required String this.label,
    required this.onPressed,
    this.variant = ChunkyButtonVariant.primary,
    this.trailingIcon,
    this.loading = false,
    this.expand = true,
    super.key,
  }) : icon = null,
       semanticLabel = null;

  /// Square icon-only variant, e.g. Directions next to the main button.
  const ChunkyButton.icon({
    required IconData this.icon,
    required String this.semanticLabel,
    required this.onPressed,
    this.variant = ChunkyButtonVariant.outline,
    super.key,
  }) : label = null,
       trailingIcon = null,
       loading = false,
       expand = false;

  final String? label;
  final IconData? icon;
  final String? semanticLabel;
  final IconData? trailingIcon;

  /// Null disables the button.
  final VoidCallback? onPressed;
  final ChunkyButtonVariant variant;

  /// Shows a spinner and ignores taps, e.g. while an order is being created.
  final bool loading;

  /// Fill the available width (labelled variant only).
  final bool expand;

  @override
  State<ChunkyButton> createState() => _ChunkyButtonState();
}

class _ChunkyButtonState extends State<ChunkyButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null && !widget.loading;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  void _handleTap() {
    unawaited(HapticFeedback.lightImpact());
    widget.onPressed!();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final semantic = context.semantic;
    final (face, onFace, deep, border) = switch (widget.variant) {
      ChunkyButtonVariant.primary => (
        colors.primary,
        colors.onPrimary,
        semantic.primaryDeep,
        null,
      ),
      ChunkyButtonVariant.accent => (
        semantic.accent,
        semantic.onAccent,
        semantic.accentDeep,
        null,
      ),
      ChunkyButtonVariant.outline => (
        colors.surfaceContainerLowest,
        colors.primary,
        colors.outlineVariant,
        colors.outlineVariant,
      ),
    };

    const depth = AppSizes.pressDepth;
    final sunk = _pressed && _enabled;
    final isIcon = widget.icon != null;
    final height = isIcon ? 56.0 : AppSizes.buttonHeight;
    final radius = BorderRadius.circular(isIcon ? AppRadius.md : 20);
    final fg = _enabled ? onFace : onFace.withValues(alpha: 0.6);

    final content = widget.loading
        ? SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(strokeWidth: 3, color: fg),
          )
        : isIcon
        ? Icon(widget.icon, color: fg, size: 24)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  widget.label!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleLarge?.copyWith(
                    color: fg,
                    fontSize: 19,
                  ),
                ),
              ),
              if (widget.trailingIcon != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Icon(widget.trailingIcon, color: fg, size: 22),
              ],
            ],
          );

    final button = Padding(
      padding: const EdgeInsets.only(bottom: depth),
      child: AnimatedContainer(
        duration: AppDurations.fast,
        curve: Curves.easeOut,
        height: height,
        width: isIcon ? height : (widget.expand ? double.infinity : null),
        padding: isIcon
            ? null
            : const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
        alignment: Alignment.center,
        transform: Matrix4.translationValues(0, sunk ? depth : 0, 0),
        decoration: BoxDecoration(
          color: _enabled ? face : face.withValues(alpha: 0.5),
          borderRadius: radius,
          border: border == null ? null : Border.all(color: border, width: 2),
          boxShadow: [
            if (_enabled && !sunk)
              BoxShadow(color: deep, offset: const Offset(0, depth)),
          ],
        ),
        child: content,
      ),
    );

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.semanticLabel,
      onTap: _enabled ? _handleTap : null,
      child: ExcludeSemantics(
        excluding: isIcon,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          // The Semantics above owns the tap action and the enabled state.
          excludeFromSemantics: true,
          onTapDown: _enabled ? (_) => _setPressed(true) : null,
          onTapUp: _enabled ? (_) => _setPressed(false) : null,
          onTapCancel: () => _setPressed(false),
          onTap: _enabled ? _handleTap : null,
          child: isIcon
              ? Tooltip(message: widget.semanticLabel, child: button)
              : button,
        ),
      ),
    );
  }
}
