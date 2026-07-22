/// Predikat murni untuk klasifikasi action hint pesan chatbot.
///
/// Dipindah dari method privat `_ChatbotScreenState` (move-only, tanpa
/// perubahan perilaku).
library;

import '../../application/chatbot_conversation_models.dart';

String friendlyLocationActionLabel(String label) {
  var text = label;
  const replacements = <String, String>{
    'Titik Jemput/Tujuan': 'Lokasi Jemput/Tujuan',
    'Titik Jemput & Tujuan': 'Lokasi Jemput/Tujuan',
    'Titik Ambil & Tujuan': 'Lokasi Ambil/Tujuan',
    'Titik Ambil/Tujuan': 'Lokasi Ambil/Tujuan',
    'Titik Jemput': 'Lokasi Jemput',
    'Titik Ambil': 'Lokasi Ambil',
    'Titik Tujuan': 'Lokasi Tujuan',
    'Titik Antar': 'Lokasi Antar',
    'Titik di Peta': 'Lokasi di Peta',
    'Pilih Tempat di Map': 'Pilih Toko/Resto',
    'Pilih Tempat': 'Pilih Toko/Resto',
    'Tambah Tempat': 'Tambah Toko/Resto',
    'Lokasi Antar': 'Alamat Antar',
  };

  for (final entry in replacements.entries) {
    text = text.replaceAll(entry.key, entry.value);
  }

  return text;
}

bool hasPaymentActionHints(List<ChatbotMessageActionHint> actionHints) {
  return actionHints.any(isPaymentActionHint);
}

bool isPaymentActionHint(ChatbotMessageActionHint actionHint) {
  final label = actionHint.label.trim().toLowerCase();
  final message = (actionHint.presetMessage ?? '').trim().toLowerCase();
  const paymentKeywords = <String>{
    'cod',
    'cash',
    'tunai',
    'transfer',
    'qris',
  };
  return actionHint.type == ChatbotMessageActionType.sendPresetMessage &&
      (paymentKeywords.contains(label) || paymentKeywords.contains(message));
}

bool isRouteEditActionHint(ChatbotMessageActionHint actionHint) {
  final label = actionHint.label.trim().toLowerCase();
  final message = (actionHint.presetMessage ?? '').trim().toLowerCase();

  return (label.contains('ubah') || label.contains('ganti')) &&
      (label.contains('tujuan') ||
          label.contains('jemput') ||
          label.contains('antar') ||
          label.contains('ambil') ||
          label.contains('lokasi') ||
          message.contains('tujuan'));
}

bool isLocationSetupActionHint(ChatbotMessageActionHint actionHint) {
  final label = actionHint.label.trim().toLowerCase();
  return (actionHint.type == ChatbotMessageActionType.openMapPicker ||
          actionHint.type == ChatbotMessageActionType.openMerchantPicker ||
          actionHint.type == ChatbotMessageActionType.openRoutePicker ||
          actionHint.type == ChatbotMessageActionType.openAddresses) &&
      (label.contains('atur') ||
          label.contains('pilih') ||
          label.contains('cari') ||
          label.contains('isi alamat'));
}

bool isMerchantMapPickerActionHint(ChatbotMessageActionHint actionHint) {
  final mode = (actionHint.merchantMode ?? '').trim().toLowerCase();
  return actionHint.type == ChatbotMessageActionType.openMerchantPicker &&
      (mode == 'maps' || mode == 'maps_add');
}

bool isAddMerchantActionHint(ChatbotMessageActionHint actionHint) {
  final mode = (actionHint.merchantMode ?? '').trim().toLowerCase();
  final label = actionHint.label.trim().toLowerCase();
  return actionHint.type == ChatbotMessageActionType.openMerchantPicker &&
      (mode == 'add' ||
          mode == 'maps_add' ||
          label.contains('tambah toko') ||
          label.contains('tambah resto'));
}

bool isConfirmationActionHint(ChatbotMessageActionHint actionHint) {
  final label = actionHint.label.trim().toLowerCase();
  final message = (actionHint.presetMessage ?? '').trim().toLowerCase();
  return actionHint.type == ChatbotMessageActionType.sendPresetMessage &&
      (label.contains('konfirmasi') || message == 'konfirmasi');
}

bool isDestinationResetActionHint(ChatbotMessageActionHint actionHint) {
  final label = actionHint.label.trim().toLowerCase();
  return actionHint.type == ChatbotMessageActionType.openRoutePicker &&
      label == 'pilih tujuan baru';
}
