import 'package:flutter_test/flutter_test.dart';
import 'package:parkspot/core/extensions/validators_x.dart';

void main() {
  test('name', () {
    expect(null.validateName(), isNotNull);
    expect('   '.validateName(), isNotNull);
    expect(('a' * 81).validateName(), isNotNull);
    expect(' Asha '.validateName(), isNull);
  });

  test('email', () {
    expect(''.validateEmail(), isNotNull);
    expect('asha'.validateEmail(), isNotNull);
    expect('asha@mail'.validateEmail(), isNotNull);
    expect('a sha@mail.com'.validateEmail(), isNotNull);
    expect(' asha@mail.com '.validateEmail(), isNull);
  });

  test('new password', () {
    expect(''.validateNewPassword(), isNotNull);
    expect('1234567'.validateNewPassword(), isNotNull);
    expect(('a' * 129).validateNewPassword(), isNotNull);
    expect('12345678'.validateNewPassword(), isNull);
  });

  test('login password only needs a value', () {
    expect(''.validatePassword(), isNotNull);
    expect('x'.validatePassword(), isNull);
  });

  test('confirm password', () {
    expect(''.validateConfirmPassword('secret12'), isNotNull);
    expect('secret13'.validateConfirmPassword('secret12'), isNotNull);
    expect('secret12'.validateConfirmPassword('secret12'), isNull);
  });

  test('required', () {
    expect(' '.validateRequired('Plate'), 'Plate is required');
    expect('MH12'.validateRequired(), isNull);
  });
}
