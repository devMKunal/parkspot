import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:parkspot/core/di/injector.dart';
import 'package:parkspot/core/extensions/context_x.dart';
import 'package:parkspot/core/extensions/validators_x.dart';
import 'package:parkspot/core/theme/app_spacing.dart';
import 'package:parkspot/core/theme/app_typography.dart';
import 'package:parkspot/core/widgets/alert_banner.dart';
import 'package:parkspot/core/widgets/app_text_field.dart';
import 'package:parkspot/core/widgets/chunky_button.dart';
import 'package:parkspot/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:parkspot/features/login/presentation/bloc/login_bloc.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({required this.onSignUp, super.key});

  /// Goes to sign-up, keeping any pending deep link.
  final VoidCallback onSignUp;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LoginBloc(getIt()),
      child: LoginView(onSignUp: onSignUp),
    );
  }
}

class LoginView extends StatefulWidget {
  const LoginView({required this.onSignUp, super.key});

  final VoidCallback onSignUp;

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    context.read<LoginBloc>().add(
      LoginSubmitted(email: _email.text, password: _password.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LoginBloc, LoginState>(
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
                            const _WelcomeArt(),
                            const SizedBox(height: AppSpacing.xxl),
                            Text(
                              'Welcome back!',
                              style: context.text.headlineLarge,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Log in to see your bookings and passes.',
                              style: context.text.bodyMedium?.copyWith(
                                color: context.colors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xxl),
                            if (state.error case final error?) ...[
                              AlertBanner(message: error),
                              const SizedBox(height: AppSpacing.xxl),
                            ],
                            AppTextField(
                              label: 'Email',
                              hintText: 'email@address.com',
                              controller: _email,
                              enabled: !busy,
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
                              errorText: state.wrongPassword
                                  ? 'Check your password'
                                  : null,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.password],
                              onFieldSubmitted: (_) => _submit(),
                              validator: (value) => value.validatePassword(),
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
                        label: 'Log in',
                        loading: busy,
                        onPressed: _submit,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'New here?',
                            style: context.text.bodyMedium?.copyWith(
                              color: context.colors.onSurfaceVariant,
                            ),
                          ),
                          TextButton(
                            onPressed: busy ? null : widget.onSignUp,
                            child: const Text('Create an account'),
                          ),
                        ],
                      ),
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

/// The header card: a road stripe, the P tile and a speech bubble.
class _WelcomeArt extends StatelessWidget {
  const _WelcomeArt();

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    final colors = context.colors;
    final ink = semantic.markerOutline;
    return ExcludeSemantics(
      child: Container(
        height: 150,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: semantic.tintViolet,
          borderRadius: BorderRadius.circular(AppRadius.sheet),
        ),
        child: Stack(
          children: [
            Positioned(
              left: -10,
              right: -10,
              top: 70,
              child: Transform.rotate(
                angle: -0.14,
                child: Container(
                  height: 16,
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 44,
              top: 30,
              child: Transform.rotate(
                angle: -0.14,
                child: Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: semantic.accent,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: ink, width: 3),
                  ),
                  child: Text(
                    'P',
                    style: TextStyle(
                      fontFamily: AppTypography.display,
                      fontWeight: FontWeight.w800,
                      fontSize: 40,
                      height: 1,
                      color: semantic.onAccent,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 28,
              top: 56,
              child: Transform.rotate(
                angle: 0.09,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: ink, width: 3),
                  ),
                  child: Text(
                    'Your spot missed you',
                    style: context.text.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
