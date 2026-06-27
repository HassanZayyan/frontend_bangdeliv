class ApiException implements Exception {
  static const String noInternetMessage =
      'Tidak ada koneksi internet. Periksa koneksi Anda, lalu coba lagi.';
  static const String timeoutMessage =
      'Koneksi lambat. Periksa koneksi Anda, lalu coba lagi.';
  static const String uploadTimeoutMessage =
      'Upload belum selesai. Periksa koneksi Anda, lalu coba lagi.';

  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  @override
  String toString() {
    if (statusCode == null) {
      return message;
    }

    return '[$statusCode] $message';
  }
}
