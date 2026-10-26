import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:parkspot/core/constants/app_constants.dart';
import 'package:parkspot/core/di/injector.dart';
import 'package:parkspot/core/extensions/context_x.dart';
import 'package:parkspot/core/extensions/validators_x.dart';
import 'package:parkspot/core/theme/app_spacing.dart';
import 'package:parkspot/core/widgets/alert_banner.dart';
import 'package:parkspot/core/widgets/app_text_field.dart';
import 'package:parkspot/core/widgets/brand_mark.dart';
import 'package:parkspot/core/widgets/chunky_button.dart';
import 'package:parkspot/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:parkspot/features/signup/presentation/bloc/signup_bloc.dart';

class SignupPage extends StatelessWidget {
  const SignupPage({required this.onLogIn, super.key});

  /// Goes to login, keeping any pending deep link.
  final VoidCallback onLogIn;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SignupBloc(getIt()),
      child: SignupView(onLogIn: onLogIn),
    );
  }
}

/// Name, email, password twice. On success it hands the user to AuthBloc
/// and the router moves on; it never navigates itself.
class SignupView extends StatefulWidget {
  const SignupView({required this.onLogIn, super.key});

  final VoidCallback onLogIn;

  @override
  State<SignupView> createState() => _SignupViewState();
}

class _SignupViewState extends State<SignupView> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    context.read<SignupBloc>().add(
      CreateAccountEvent(
        name: _name.text,
        email: _email.text,
        password: _password.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SignupBloc, SignupState>(
      listenWhen: (previous, current) =>
          current.user != null && current.user != previous.user,
      listener: (context, state) =>
          context.read<AuthBloc>().add(AuthLoggedIn(state.user!)),
      builder: (context, state) {
        final busy = state.status.isSubmitting;
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xxl,
                      AppSpacing.xxxl,
                      AppSpacing.xxl,
                      AppSpacing.xxl,
                    ),
                    child: Form(
                      key: _formKey,
                      child: AutofillGroup(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: BrandMark(),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              "Let's get you parked",
                              style: context.text.headlineLarge,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'Create your account in under a minute.',
                              style: context.text.bodyMedium?.copyWith(
                                color: context.colors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xl),
                            if (state.error case final error?) ...[
                              AlertBanner(message: error),
                              const SizedBox(height: AppSpacing.lg),
                            ],
                            AppTextField(
                              label: 'Your name',
                              hintText: 'John Doe',
                              controller: _name,
                              enabled: !busy,
                              keyboardType: TextInputType.name,
                              textInputAction: TextInputAction.next,
                              textCapitalization: TextCapitalization.words,
                              autofillHints: const [AutofillHints.name],
                              validator: (value) => value.validateName(),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            AppTextField(
                              label: 'Email',
                              hintText: 'email@address.com',
                              controller: _email,
                              enabled: !busy,
                              errorText: state.emailError,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.email],
                              validator: (value) => value.validateEmail(),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            AppTextField(
                              label: 'Password',
                              hintText: 'Enter password',
                              controller: _password,
                              enabled: !busy,
                              obscure: true,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.newPassword],
                              helper: _PasswordHint(_password),
                              validator: (value) => value.validateNewPassword(),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            AppTextField(
                              label: 'Confirm password',
                              hintText: 'Confirm password',
                              controller: _confirmPassword,
                              enabled: !busy,
                              obscure: true,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                              validator: (value) =>
                                  value.validateConfirmPassword(_password.text),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xxl,
                    AppSpacing.sm,
                    AppSpacing.xxl,
                    AppSpacing.lg,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ChunkyButton(
                        label: 'Create account',
                        loading: busy,
                        onPressed: _submit,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      _LogInLink(onPressed: busy ? null : widget.onLogIn),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Live strength hint under the password: grey until it meets the rule,
/// then a green check, as in the design.
class _PasswordHint extends StatelessWidget {
  const _PasswordHint(this.password);

  final TextEditingController password;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: password,
      builder: (context, value, _) {
        final ok = value.text.length >= AppConstants.passwordMinLength;
        final color = ok
            ? context.semantic.success
            : context.colors.onSurfaceVariant;
        return Row(
          children: [
            if (ok) ...[
              Icon(Icons.check_rounded, size: 16, color: color),
              const SizedBox(width: AppSpacing.xs),
            ],
            Text(
              ok
                  ? '${AppConstants.passwordMinLength}+ characters, '
                        'nice and strong'
                  : 'At least ${AppConstants.passwordMinLength} characters',
              style: context.text.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LogInLink extends StatelessWidget {
  const _LogInLink({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Already have an account?',
          style: context.text.bodyMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        TextButton(onPressed: onPressed, child: const Text('Log in')),
      ],
    );
  }
}
