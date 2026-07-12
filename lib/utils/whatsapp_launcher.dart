import 'package:url_launcher/url_launcher.dart';

typedef OrderWhatsAppLauncher = Future<bool> Function(Uri uri);

String? normalizeIndonesianWhatsAppNumber(String? rawPhone) {
  var digits = (rawPhone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.startsWith('0')) {
    digits = '62${digits.substring(1)}';
  } else if (digits.startsWith('8')) {
    digits = '62$digits';
  }

  if (!digits.startsWith('62') || digits.length < 10 || digits.length > 15) {
    return null;
  }

  return digits;
}

Uri? buildOrderWhatsAppUri({
  required String? phone,
  required String participantName,
  required Object orderId,
}) {
  final normalizedPhone = normalizeIndonesianWhatsAppNumber(phone);
  if (normalizedPhone == null) {
    return null;
  }

  final safeName = participantName.trim().isEmpty
      ? 'Kak'
      : participantName.trim();
  return Uri.https('wa.me', '/$normalizedPhone', <String, String>{
    'text':
        'Halo $safeName, saya menghubungi terkait order BangDeliv #$orderId.',
  });
}

Future<bool> launchOrderWhatsApp(Uri uri, {OrderWhatsAppLauncher? launcher}) {
  if (launcher != null) {
    return launcher(uri);
  }

  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
