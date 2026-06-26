import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../config/app_colors.dart';
import '../../../../config/app_routes.dart';
import '../../../../config/app_text_scaling.dart';
import '../../../../core/widgets/bang_async_state.dart';
import '../../../../models/driver_verification_model.dart';
import '../../../auth/application/auth_session_provider.dart';
import '../../../../services/driver_verification_service.dart';

class DriverVerificationStatusScreen extends ConsumerStatefulWidget {
  const DriverVerificationStatusScreen({super.key});

  @override
  ConsumerState<DriverVerificationStatusScreen> createState() =>
      _DriverVerificationStatusScreenState();
}

class _DriverVerificationStatusScreenState
    extends ConsumerState<DriverVerificationStatusScreen> {
  static const List<String> _orderedDocumentTypes = ['ktp', 'sim', 'selfie'];
  static const double _pickerIconSize = 20;
  static const TextStyle _pickerLabelStyle = TextStyle(fontSize: 14);

  final ImagePicker _imagePicker = ImagePicker();
  DriverVerificationStatusModel? _status;
  String? _errorMessage;
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isCancelling = false;

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
      return _withProfileBackHandling(
        const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    if (_errorMessage != null && _status == null) {
      return _withProfileBackHandling(
        Scaffold(
          appBar: _buildAppBar(),
          body: BangErrorState(message: _errorMessage!, onRetry: _loadStatus),
        ),
      );
    }

    final status = _status;
    if (status == null) {
      return _withProfileBackHandling(
        Scaffold(
          appBar: _buildAppBar(),
          body: BangErrorState(
            message: 'Status verifikasi driver tidak ditemukan.',
            onRetry: _loadStatus,
          ),
        ),
      );
    }

    final registrationStatus = status.driver.registrationStatus
        .trim()
        .toLowerCase();
    final isActive = registrationStatus == 'active';
    final canUpload = _canUpload(registrationStatus);
    final canCancel = _canCancel(registrationStatus);

    return _withProfileBackHandling(
      Scaffold(
        backgroundColor: AppColors.background,
        appBar: _buildAppBar(),
        body: RefreshIndicator(
          onRefresh: _loadStatus,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
            children: [
              _StatusCard(
                title: _titleFor(registrationStatus),
                description: _descriptionFor(registrationStatus),
                registrationStatus: registrationStatus,
              ),
              const SizedBox(height: 16),
              const Text(
                'Dokumen Verifikasi',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isActive
                    ? 'Dokumen Anda sudah selesai diverifikasi admin.'
                    : canUpload
                    ? 'Unggah KTP, SIM, dan selfie untuk proses review admin.'
                    : 'Upload dokumen dinonaktifkan untuk status akun driver saat ini.',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                  height: 1.35,
                ),
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
                    isAccountActive: isActive,
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
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ),
                ),
              if (canUpload) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitDocuments,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.white,
                            ),
                          )
                        : const Text('Kirim Dokumen'),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              if (!isActive) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading || _isCancelling ? null : _loadStatus,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh Status'),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              if (canCancel) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isSubmitting || _isCancelling
                        ? null
                        : _confirmCancelApplication,
                    icon: _isCancelling
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.close_rounded),
                    label: Text(
                      _isCancelling ? 'Membatalkan...' : 'Batalkan Pengajuan',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _withProfileBackHandling(Widget child) {
    return PopScope(
      canPop: Navigator.of(context).canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }

        _backFromStatus();
      },
      child: child,
    );
  }

  void _backFromStatus() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }

    final session = ref.read(authSessionProvider);
    final isDriverActive =
        session.driverAccessState == DriverAccessState.active;

    context.go(isDriverActive ? AppRoutes.driverProfile : AppRoutes.profile);
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: const Text(
        'Status Verifikasi Driver',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      automaticallyImplyLeading: false,
      leading: IconButton(
        onPressed: _backFromStatus,
        icon: const Icon(Icons.arrow_back),
        tooltip: 'Kembali',
      ),
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

      await ref.read(authSessionProvider.notifier).refreshSession();
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
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
      ),
      clipBehavior: Clip.antiAlias,
      builder: (context) {
        return Material(
          color: AppColors.white,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    tileColor: AppColors.white,
                    leading: const Icon(
                      Icons.camera_alt_outlined,
                      size: _pickerIconSize,
                    ),
                    title: const Text(
                      'Ambil dari Kamera',
                      style: _pickerLabelStyle,
                    ),
                    onTap: () => Navigator.of(context).pop(ImageSource.camera),
                  ),
                  ListTile(
                    tileColor: AppColors.white,
                    leading: const Icon(
                      Icons.photo_library_outlined,
                      size: _pickerIconSize,
                    ),
                    title: const Text(
                      'Pilih dari Galeri',
                      style: _pickerLabelStyle,
                    ),
                    onTap: () => Navigator.of(context).pop(ImageSource.gallery),
                  ),
                ],
              ),
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

  Future<void> _confirmCancelApplication() async {
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Batalkan Pengajuan?'),
          content: const Text(
            'Pengajuan driver akan dibatalkan. Anda tetap bisa memakai BangDeliv sebagai customer dan dapat mengajukan driver lagi nanti.',
          ),
          actions: [
            TextButton(
              onPressed: () => dialogContext.pop(false),
              child: const Text('Tetap Lanjut'),
            ),
            FilledButton(
              onPressed: () => dialogContext.pop(true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('Batalkan'),
            ),
          ],
        );
      },
    );

    if (shouldCancel == true) {
      await _cancelApplication();
    }
  }

  Future<void> _cancelApplication() async {
    if (_isCancelling) {
      return;
    }

    setState(() {
      _isCancelling = true;
      _errorMessage = null;
    });

    try {
      await DriverVerificationService.cancelApplication();
      await ref.read(authSessionProvider.notifier).refreshSession();

      if (!mounted) {
        return;
      }

      context.go(AppRoutes.profile);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Pengajuan driver berhasil dibatalkan.'),
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
          _isCancelling = false;
        });
      }
    }
  }

  bool _canUpload(String registrationStatus) {
    return registrationStatus != 'active' && registrationStatus != 'suspended';
  }

  bool _canCancel(String registrationStatus) {
    return registrationStatus == 'pending' || registrationStatus == 'rejected';
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          AppTextScaling.clampForCompactComponent(
            context: context,
            maxScaleFactor: AppTextScaling.denseComponentMaxScaleFactor,
            child: _InlineStatusLabel(
              label: _statusLabel(registrationStatus),
              color: badgeColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12.5,
              height: 1.35,
            ),
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

  String _statusLabel(String status) {
    switch (status.trim().toLowerCase()) {
      case 'active':
      case 'approved':
        return 'Disetujui';
      case 'pending':
      case 'submitted':
      case 'review':
        return 'Menunggu Verifikasi';
      case 'rejected':
        return 'Perlu Revisi';
      case 'suspended':
        return 'Ditangguhkan';
      default:
        return 'Status Tidak Dikenal';
    }
  }
}

class _DocumentCard extends StatelessWidget {
  final String documentType;
  final DriverVerificationDocumentModel? document;
  final XFile? selectedFile;
  final bool isAccountActive;
  final bool enabled;
  final VoidCallback onPickPressed;

  const _DocumentCard({
    required this.documentType,
    required this.document,
    required this.selectedFile,
    required this.isAccountActive,
    required this.enabled,
    required this.onPickPressed,
  });

  @override
  Widget build(BuildContext context) {
    final docName = _displayName(documentType);
    final verificationStatus = (document?.verificationStatus ?? 'pending')
        .trim()
        .toLowerCase();
    final isUploaded = document?.isUploaded == true;
    final statusColor = isUploaded
        ? _statusColor(verificationStatus)
        : AppColors.textSecondary;

    if (isAccountActive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                docName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Icon(
              Icons.check_circle_outline_rounded,
              size: 20,
              color: AppColors.success,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            docName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: AppTextScaling.clampForCompactComponent(
              context: context,
              maxScaleFactor: AppTextScaling.denseComponentMaxScaleFactor,
              child: _InlineStatusLabel(
                label: _documentStatusLabel(
                  verificationStatus,
                  isUploaded: isUploaded,
                ),
                color: statusColor,
              ),
            ),
          ),
          if ((document?.rejectionReason ?? '').trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'Alasan ditolak: ${document!.rejectionReason}',
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(height: 12),
          _DocumentFileInfo(
            isUploaded: isUploaded,
            selectedFileName: selectedFile?.name,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: enabled ? onPickPressed : null,
              icon: const Icon(Icons.upload_file_outlined, size: 18),
              label: Text(
                selectedFile == null ? 'Pilih Dokumen' : 'Ganti Dokumen',
              ),
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
        return 'Selfie';
      default:
        return type;
    }
  }

  String _documentStatusLabel(String status, {required bool isUploaded}) {
    if (!isUploaded) {
      return 'Belum diunggah';
    }

    switch (status.trim().toLowerCase()) {
      case 'approved':
        return 'Disetujui';
      case 'rejected':
        return 'Perlu Revisi';
      case 'pending':
      case 'submitted':
      case 'review':
      default:
        return 'Menunggu';
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

class _InlineStatusLabel extends StatelessWidget {
  const _InlineStatusLabel({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DocumentFileInfo extends StatelessWidget {
  const _DocumentFileInfo({
    required this.isUploaded,
    required this.selectedFileName,
  });

  final bool isUploaded;
  final String? selectedFileName;

  @override
  Widget build(BuildContext context) {
    final hasSelectedFile =
        selectedFileName != null && selectedFileName!.isNotEmpty;
    final label = hasSelectedFile
        ? 'File baru'
        : isUploaded
        ? 'File tersimpan'
        : 'Belum ada file dipilih';
    final value = hasSelectedFile ? selectedFileName! : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.insert_drive_file_outlined,
            size: 18,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (value != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
