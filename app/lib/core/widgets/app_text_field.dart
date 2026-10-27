import 'package:flutter/material.dart';
import 'package:parkspot/core/extensions/context_x.dart';
import 'package:parkspot/core/theme/app_spacing.dart';

/// A labelled text field: bold label above, themed field below.
///
/// With [obscure] it becomes a password field with a show/hide toggle.
/// Validation and error text come from the caller (your form BLoC); this
/// widget only renders them.
class AppTextField extends StatefulWidget {
  const AppTextField({
    required this.label,
    this.controller,
    this.hintText,
    this.helperText,
    this.helper,
    this.errorText,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.obscure = false,
    this.enabled = true,
    this.onChanged,
    this.onFieldSubmitted,
    this.validator,
    this.focusNode,
    this.textCapitalization = TextCapitalization.none,
    super.key,
  });

  final String label;
  final TextEditingController? controller;
  final String? hintText;
  final String? helperText;

  /// A widget in place of [helperText], e.g. a check icon with the text.
  final Widget? helper;

  /// Shown under the field with an error border; null clears it.
  final String? errorText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final bool obscure;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final FormFieldValidator<String>? validator;
  final FocusNode? focusNode;
  final TextCapitalization textCapitalization;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.label, style: context.text.labelLarge),
        const SizedBox(height: AppSpacing.xs + 2),
        TextFormField(
          textCapitalization: widget.textCapitalization,
          controller: widget.controller,
          focusNode: widget.focusNode,
          enabled: widget.enabled,
          obscureText: _hidden,
          enableSuggestions: !widget.obscure,
          autocorrect: !widget.obscure,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          autofillHints: widget.autofillHints,
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onFieldSubmitted,
          validator: widget.validator,
          style: context.text.bodyLarge,
          decoration: InputDecoration(
            hintText: widget.hintText,
            helperText: widget.helperText,
            helper: widget.helper,
            errorText: widget.errorText,
            errorMaxLines: 2,
            suffixIcon: widget.obscure
                ? IconButton(
                    tooltip: _hidden ? 'Show password' : 'Hide password',
                    icon: Icon(
                      _hidden
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () => setState(() => _hidden = !_hidden),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}
