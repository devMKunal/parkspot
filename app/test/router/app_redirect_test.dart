import 'package:flutter_test/flutter_test.dart';
import 'package:parkspot/router/app_redirect.dart';
import 'package:parkspot/router/auth_status.dart';

void main() {
  String? redirect(
    String location,
    AuthStatus auth, {
    bool onboardingSeen = true,
  }) => appRedirect(
    uri: Uri.parse(location),
    auth: auth,
    onboardingSeen: onboardingSeen,
  );

  group('while the session is unknown', () {
    const auth = AuthStatus.unknown;

    test('holds on the splash', () {
      expect(redirect('/splash', auth), isNull);
      expect(redirect('/', auth), '/splash');
      expect(redirect('/login', auth), '/splash');
    });

    test('remembers a deep link', () {
      expect(redirect('/bookings/b1', auth), '/splash?from=%2Fbookings%2Fb1');
    });

    test('leaves dev tools open', () {
      expect(redirect('/dev/gallery', auth), isNull);
    });
  });

  group('signed out', () {
    const auth = AuthStatus.unauthenticated;

    test('leaves the splash for onboarding on first launch', () {
      expect(redirect('/splash', auth, onboardingSeen: false), '/onboarding');
    });

    test('leaves the splash for login after that', () {
      expect(redirect('/splash', auth), '/login');
    });

    test('keeps the deep link from the splash', () {
      expect(
        redirect('/splash?from=%2Fbookings%2Fb1', auth),
        '/login?from=%2Fbookings%2Fb1',
      );
    });

    test('may open any auth page', () {
      for (final path in ['/onboarding', '/signup', '/login']) {
        expect(redirect(path, auth, onboardingSeen: false), isNull);
        expect(redirect(path, auth), isNull);
      }
    });

    test('is sent to login from a private page, with the way back', () {
      expect(redirect('/', auth), '/login');
      expect(
        redirect('/lots/l1/book', auth),
        '/login?from=%2Flots%2Fl1%2Fbook',
      );
      expect(redirect('/trips', auth), '/login?from=%2Ftrips');
    });
  });

  group('signed in', () {
    const auth = AuthStatus.authenticated;

    test('goes from the splash and auth pages to the map', () {
      for (final path in ['/splash', '/onboarding', '/signup', '/login']) {
        expect(redirect(path, auth), '/');
      }
    });

    test('goes on to the deep link', () {
      expect(redirect('/login?from=%2Fbookings%2Fb1', auth), '/bookings/b1');
      expect(redirect('/splash?from=%2Ftrips', auth), '/trips');
    });

    test('may open any private page', () {
      for (final path in ['/', '/permission', '/bookings/b1/paid']) {
        expect(redirect(path, auth), isNull);
      }
    });

    test('ignores a from that leaves the app or loops', () {
      for (final from in ['https://evil.example', '//evil.example', '/login']) {
        final location = Uri(
          path: '/login',
          queryParameters: {'from': from},
        ).toString();
        expect(redirect(location, auth), '/', reason: from);
      }
    });
  });
}
