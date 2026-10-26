import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/foundation.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parkspot/features/auth/domain/auth_repository.dart';
import 'package:parkspot/features/auth/domain/user.dart';
import 'package:parkspot/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:parkspot/features/onboarding/domain/onboarding_status.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

final testUser = User(
  id: 'u1',
  name: 'Asha',
  email: 'asha@mail.com',
  createdAt: DateTime.utc(2026, 10, 1, 10),
);

/// [OnboardingStatus] that forgets on restart.
class InMemoryOnboardingStatus implements OnboardingStatus {
  InMemoryOnboardingStatus({bool seen = false}) : _seen = ValueNotifier(seen);

  final ValueNotifier<bool> _seen;

  @override
  ValueListenable<bool> get seen => _seen;

  @override
  Future<void> markSeen() async => _seen.value = true;
}
