import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../models/driver_verification_model.dart';
import '../providers/auth_session_provider.dart';
import '../services/driver_verification_service.dart';

class DriverVerificationStatusScreen extends ConsumerStatefulWidget {
  const DriverVerificationStatusScreen({super.key});

  @override
  ConsumerState<DriverVerificationStatusScreen> createState() =>
      _DriverVerificationStatusScreenState();
}

class _DriverVerificationStatusScreenState
    extends ConsumerState<DriverVerificationStatusScreen> {
  static const List<String> _orderedDocumentTypes = ['ktp', 'sim', 'selfie'];

  final ImagePicker _imagePicker = ImagePicker();
  DriverVerificationStatusModel? _status;
  String? _errorMessage;
  bool _isLoading = true;
  bool _isSubmitting = false;

  final Map<String, XFile?> _selectedDocuments = {
    'ktp': null,
    'sim': null,
    'selfie': null,
  };

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _status == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_errorMessage != null && _status == null) {
      return Scaffold(
        appBar: _buildAppBar(),
        body: _ErrorState(message: _errorMessage!, onRetry: _loadStatus),
      );
    }

    final status = _status;
    if (status == null) {
      return Scaffold(
        appBar: _buildAppBar(),
        body: _ErrorState(
          message: 'Status verifikasi driver tidak ditemukan.',
          onRetry: _loadStatus,
        ),
      );
    }

    final registrationStatus = status.driver.registrationStatus
        .trim()
        .toLowerCase();
    final canUpload = _canUpload(registrationStatus);

    return Scaffold(
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: _loadStatus,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _StatusCard(
              title: _titleFor(registrationStatus),
              description: _descriptionFor(registrationStatus),
              registrationStatus: registrationStatus,
            ),
            const SizedBox(height: 16),
            const Text(
              'Dokumen Verifikasi',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              canUpload
                  ? 'Pilih dokumen dari kamera atau galeri. Anda bisa unggah minimal satu dokumen setiap pengajuan.'
                  : 'Upload dokumen dinonaktifkan untuk status akun driver saat ini.',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            ..._orderedDocumentTypes.map((documentType) {
              final document = status.documentByType(documentType);
              final selectedFile = _selectedDocuments[documentType];

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _DocumentCard(
                  documentType: documentType,
                  document: document,
                  selectedFile: selectedFile,
                  enabled: canUpload && !_isSubmitting,
                  onPickPressed: () => _openPickerSheet(documentType),
                ),
              );
            }),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (!_isSubmitting && canUpload)
                    ? _submitDocuments
                    : null,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.white,
                        ),
                      )
                    : const Icon(Icons.upload_file_outlined),
                label: Text(_isSubmitting ? 'Mengunggah...' : 'Kirim Dokumen'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _loadStatus,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh Status'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.go(AppRoutes.profile),
                icon: const Icon(Icons.person_outline),
                label: const Text('Kembali ke Profil'),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Anda tidak perlu menunggu di halaman ini. Anda bisa kembali ke profil dan cek status secara berkala.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleLogout() async {
    await ref.read(authSessionProvider.notifier).logout();

    if (!mounted) {
      return;
    }

    context.go(AppRoutes.login);
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: const Text('Status Verifikasi Driver'),
      automaticallyImplyLeading: false,
      leading: IconButton(
        onPressed: () => context.go(AppRoutes.profile),
        icon: const Icon(Icons.person_outline),
        tooltip: 'Ke Profil',
      ),
      actions: [
        IconButton(
          onPressed: _handleLogout,
          icon: const Icon(Icons.logout),
          tooltip: 'Keluar',
        ),
      ],
    );
  }

  Future<void> _loadStatus() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await DriverVerificationService.fetchMyStatus();

      if (!mounted) {
        return;
      }

      setState(() {
        _status = data;
      });
    } on DriverVerificationException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = e.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openPickerSheet(String documentType) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined),
                  title: const Text('Ambil dari Kamera'),
                  onTap: () => Navigator.of(context).pop(ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Pilih dari Galeri'),
                  onTap: () => Navigator.of(context).pop(ImageSource.gallery),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (source == null) {
      return;
    }

    try {
      final file = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
      );

      if (!mounted || file == null) {
        return;
      }

      setState(() {
        _selectedDocuments[documentType] = file;
        _errorMessage = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Gagal memilih gambar. Coba lagi.'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  Future<void> _submitDocuments() async {
    if (_isSubmitting) {
      return;
    }

    final hasSelection = _selectedDocuments.values.any((file) => file != null);
    if (!hasSelection) {
      setState(() {
        _errorMessage = 'Pilih minimal satu dokumen sebelum mengirim.';
      });

      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final updated = await DriverVerificationService.submitDocuments(
        ktp: _selectedDocuments['ktp'],
        sim: _selectedDocuments['sim'],
        selfie: _selectedDocuments['selfie'],
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _status = updated;
        _selectedDocuments.updateAll((key, value) => null);
      });

      await ref.read(authSessionProvider.notifier).refreshSession();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Dokumen berhasil diunggah.'),
          backgroundColor: Colors.green.shade600,
        ),
      );
    } on DriverVerificationException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = e.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  bool _canUpload(String registrationStatus) {
    return registrationStatus != 'active' && registrationStatus != 'suspended';
  }

  String _titleFor(String registrationStatus) {
    switch (registrationStatus) {
      case 'active':
        return 'Akun Driver Aktif';
      case 'pending':
        return 'Verifikasi Sedang Diproses';
      case 'rejected':
        return 'Perlu Perbaikan Dokumen';
      case 'suspended':
        return 'Akun Driver Disuspend';
      default:
        return 'Status Verifikasi Tidak Dikenal';
    }
  }

  String _descriptionFor(String registrationStatus) {
    switch (registrationStatus) {
      case 'active':
        return 'Akun driver Anda sudah aktif. Upload dokumen tidak diperlukan lagi.';
      case 'pending':
        return 'Pengajuan Anda sedang ditinjau admin. Anda tetap dapat memperbarui dokumen jika diperlukan.';
      case 'rejected':
        return 'Sebagian dokumen ditolak. Silakan unggah dokumen pengganti sesuai catatan admin.';
      case 'suspended':
        return 'Akun Anda sedang disuspend. Hubungi admin untuk informasi lanjutan.';
      default:
        return 'Sistem belum dapat menentukan status akun driver Anda secara pasti.';
    }
  }
}

class _StatusCard extends StatelessWidget {
  final String title;
  final String description;
  final String registrationStatus;

  const _StatusCard({
    required this.title,
    required this.description,
    required this.registrationStatus,
  });

  @override
  Widget build(BuildContext context) {
    final badgeColor = _badgeColor(registrationStatus);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              registrationStatus.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: badgeColor,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Color _badgeColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green.shade700;
      case 'pending':
        return Colors.amber.shade800;
      case 'rejected':
        return Colors.red.shade700;
      case 'suspended':
        return Colors.grey.shade700;
      default:
        return Colors.blueGrey.shade600;
    }
  }
}

class _DocumentCard extends StatelessWidget {
  final String documentType;
  final DriverVerificationDocumentModel? document;
  final XFile? selectedFile;
  final bool enabled;
  final VoidCallback onPickPressed;

  const _DocumentCard({
    required this.documentType,
    required this.document,
    required this.selectedFile,
    required this.enabled,
    required this.onPickPressed,
  });

  @override
  Widget build(BuildContext context) {
    final docName = _displayName(documentType);
    final verificationStatus = (document?.verificationStatus ?? 'pending')
        .trim()
        .toLowerCase();
    final statusColor = _statusColor(verificationStatus);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.insert_drive_file_outlined,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  docName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  verificationStatus.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            document?.isUploaded == true
                ? 'Dokumen sudah pernah diunggah.'
                : 'Dokumen belum diunggah.',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          if ((document?.rejectionReason ?? '').trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Alasan ditolak: ${document!.rejectionReason}',
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (selectedFile != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Dipilih: ${selectedFile!.name}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: enabled ? onPickPressed : null,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('Pilih Kamera / Galeri'),
            ),
          ),
        ],
      ),
    );
  }

  String _displayName(String type) {
    switch (type.trim().toLowerCase()) {
      case 'ktp':
        return 'KTP';
      case 'sim':
        return 'SIM';
      case 'selfie':
        return 'Selfie dengan SIM';
      default:
        return type;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green.shade700;
      case 'rejected':
        return Colors.red.shade700;
      default:
        return Colors.amber.shade800;
    }
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }
}
