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
    expect(profile.requiresPhoneVerification, isFalse);
  });

  test('parses phone verification flag for unverified numbers', () {
    final profile = UserProfileModel.fromJson({
      'id': 8,
      'name': 'New Customer',
      'phone': '081234567890',
      'email': 'new.customer@example.com',
      'role': 'customer',
      'requires_phone_completion': false,
      'requires_phone_verification': true,
      'stats': {'total_orders': 0, 'total_paid': 0},
      'addresses': [],
    });

    expect(profile.requiresPhoneCompletion, isFalse);
    expect(profile.requiresPhoneVerification, isTrue);
  });

  test('defaults verification flag to false when the key is absent', () {
    final profile = UserProfileModel.fromJson({
      'id': 9,
      'name': 'Legacy Payload',
      'phone': '081234567891',
      'email': 'legacy@example.com',
      'role': 'customer',
      'stats': {'total_orders': 0, 'total_paid': 0},
      'addresses': [],
    });

    expect(profile.requiresPhoneVerification, isFalse);
  });
}
