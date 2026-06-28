import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bangdeliv/models/user_profile_model.dart';

void main() {
  test('parses auth provider and phone completion flags', () {
    final profile = UserProfileModel.fromJson({
      'id': 7,
      'name': 'Google User',
      'phone': '',
      'email': 'google.user@example.com',
      'role': 'customer',
      'auth_provider': 'google',
      'has_password': false,
      'requires_phone_completion': true,
      'stats': {'total_orders': 0, 'total_paid': 0},
      'addresses': [],
    });

    expect(profile.authProvider, 'google');
    expect(profile.hasPassword, isFalse);
    expect(profile.requiresPhoneCompletion, isTrue);
  });
}
