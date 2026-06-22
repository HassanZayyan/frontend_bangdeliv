import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/app_colors.dart';
import '../../../../config/app_routes.dart';
import '../../../../models/user_profile_model.dart';
import '../../application/auth_session_provider.dart';
import '../../../../services/auth_service.dart';
import '../../../../widgets/vehicle_info_fields.dart';

class RegisterDriverScreen extends ConsumerStatefulWidget {
  const RegisterDriverScreen({super.key});

  @override
  ConsumerState<RegisterDriverScreen> createState() =>
      _RegisterDriverScreenState();
}

class _RegisterDriverScreenState extends ConsumerState<RegisterDriverScreen> {
  final _formKey = GlobalKey<FormState>();
  final _platePrefixController = TextEditingController();
  final _plateNumberController = TextEditingController();
  final _plateSuffixController = TextEditingController();
  final _platePrefixFocusNode = FocusNode();
  final _plateNumberFocusNode = FocusNode();
  final _plateSuffixFocusNode = FocusNode();
  String? _selectedVehicleType;
  String? _selectedVehicleBrand;
  final _vehicleModelController = TextEditingController();
  bool _isSubmitting = false;
  bool _showPlateError = false;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionProvider);
    final profile = session.profile;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Upgrade Jadi Driver',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: ColoredBox(
          color: Colors.transparent,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _hero(context)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                  child: _formCard(context, profile),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hero(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 344, minHeight: 104),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 56,
                child: Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Siap jadi mitra pengantar?',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppColors.darkBlue,
                          fontSize: 17,
                          height: 1.25,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Lengkapi data kendaraan untuk proses verifikasi.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 44,
                child: Semantics(
                  label: 'Ilustrasi driver BangDeliv',
                  image: true,
                  child: Image.asset(
                    'assets/images/bangdeliv.png',
                    height: 96,
                    fit: BoxFit.contain,
                    alignment: Alignment.centerRight,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _formCard(BuildContext context, UserProfileModel? profile) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 344),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(22),
              bottom: Radius.circular(22),
            ),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.045),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: _form(context, profile),
        ),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Data Kendaraan',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppColors.darkBlue,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Pastikan data sesuai kendaraan yang akan digunakan.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
            fontSize: 11.5,
            height: 1.32,
          ),
        ),
      ],
    );
  }

  Widget _profileField({required String label, required String value}) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.border),
    );

    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        isDense: true,
        filled: true,
        fillColor: AppColors.background,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: border,
        enabledBorder: border,
      ),
      child: Text(
        value.isEmpty ? '-' : value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  InputDecoration _plainInputDecoration({
    String? labelText,
    required String hintText,
  }) {
    final borderColor = _showPlateError ? AppColors.error : AppColors.border;

    return InputDecoration(
      labelText: labelText,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      labelStyle: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      hintText: hintText,
      isDense: true,
      filled: true,
      fillColor: AppColors.white,
      hintStyle: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
      ),
    );
  }

  Widget _submitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _handleUpgrade,
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.white,
                ),
              )
            : const Text(
                'Kirim Pengajuan Driver',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
      ),
    );
  }

  Widget _form(BuildContext context, UserProfileModel? profile) {
    final name = (profile?.name ?? '').toString();
    final email = (profile?.email ?? '').toString();

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(context),
          const SizedBox(height: 22),
          _profileField(label: 'Nama', value: name),
          const SizedBox(height: 16),
          _profileField(label: 'Email', value: email),
          const SizedBox(height: 18),
          VehicleInfoFields(
            selectedVehicleType: _selectedVehicleType,
            selectedVehicleBrand: _selectedVehicleBrand,
            vehicleModelController: _vehicleModelController,
            enabled: !_isSubmitting,
            showLabels: true,
            filled: true,
            fillColor: AppColors.white,
            vehicleTypeLabel: 'Jenis Motor',
            labelColor: AppColors.textSecondary,
            labelFontSize: 12,
            labelBottomSpacing: 4,
            fieldSpacing: 12,
            borderRadius: 10,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            isDense: true,
            showIcons: false,
            capitalizeVehicleModel: true,
            onVehicleTypeChanged: (value) {
              setState(() {
                _selectedVehicleType = value;
                if ((value ?? '').trim().isEmpty) {
                  _selectedVehicleBrand = null;
                  _vehicleModelController.clear();
                }
              });
            },
            onVehicleBrandChanged: (value) {
              setState(() {
                _selectedVehicleBrand = value;
                if ((value ?? '').trim().isEmpty) {
                  _vehicleModelController.clear();
                }
              });
            },
          ),
          const SizedBox(height: 16),
          _buildVehiclePlateFields(),
          const SizedBox(height: 14),
          Text(
            'Data akan ditinjau sebelum akun driver aktif.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              fontSize: 11.5,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 18),
          _submitButton(),
        ],
      ),
    );
  }

  Widget _buildVehiclePlateFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: _platePrefixController,
                focusNode: _platePrefixFocusNode,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.characters,
                keyboardType: TextInputType.text,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z]')),
                  LengthLimitingTextInputFormatter(2),
                  _UpperCaseTextFormatter(),
                ],
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
                decoration: _plainInputDecoration(
                  labelText: 'Kode',
                  hintText: 'H',
                ),
                onChanged: (_) {
                  if (_showPlateError && _isPlateComplete()) {
                    setState(() {
                      _showPlateError = false;
                    });
                  }
                },
                onFieldSubmitted: (_) {
                  _plateNumberFocusNode.requestFocus();
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 4,
              child: TextFormField(
                controller: _plateNumberController,
                focusNode: _plateNumberFocusNode,
                textInputAction: TextInputAction.next,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
                decoration: _plainInputDecoration(
                  labelText: 'Nomor',
                  hintText: '1234',
                ),
                onChanged: (_) {
                  if (_showPlateError && _isPlateComplete()) {
                    setState(() {
                      _showPlateError = false;
                    });
                  }
                },
                onFieldSubmitted: (_) {
                  _plateSuffixFocusNode.requestFocus();
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 4,
              child: TextFormField(
                controller: _plateSuffixController,
                focusNode: _plateSuffixFocusNode,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.characters,
                keyboardType: TextInputType.text,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z]')),
                  LengthLimitingTextInputFormatter(3),
                  _UpperCaseTextFormatter(),
                ],
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
                decoration: _plainInputDecoration(
                  labelText: 'Seri',
                  hintText: 'ABC',
                ),
                onChanged: (_) {
                  if (_showPlateError && _isPlateComplete()) {
                    setState(() {
                      _showPlateError = false;
                    });
                  }
                },
                onFieldSubmitted: (_) {
                  FocusScope.of(context).requestFocus();
                },
              ),
            ),
          ],
        ),
        if (_showPlateError) ...[
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.only(left: 12),
            child: Text(
              'Nomor plat kendaraan wajib diisi',
              style: TextStyle(color: AppColors.error, fontSize: 12),
            ),
          ),
        ],
      ],
    );
  }

  String _buildVehiclePlate() {
    final prefix = _platePrefixController.text.trim().toUpperCase();
    final number = _plateNumberController.text.trim();
    final suffix = _plateSuffixController.text.trim().toUpperCase();

    return '$prefix $number $suffix';
  }

  bool _isPlateComplete() {
    return _platePrefixController.text.trim().isNotEmpty &&
        _plateNumberController.text.trim().isNotEmpty &&
        _plateSuffixController.text.trim().isNotEmpty;
  }

  Future<void> _handleUpgrade() async {
    if (_isSubmitting) {
      return;
    }

    final currentState = _formKey.currentState;
    final isPlateComplete = _isPlateComplete();
    setState(() {
      _showPlateError = !isPlateComplete;
    });

    if (currentState == null || !currentState.validate() || !isPlateComplete) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await AuthService.upgradeToDriver(
        vehicleType: (_selectedVehicleType ?? '').trim(),
        vehicleBrand: (_selectedVehicleBrand ?? '').trim(),
        vehicleModel: _vehicleModelController.text.trim(),
        vehiclePlate: _buildVehiclePlate(),
      );

      await ref.read(authSessionProvider.notifier).refreshSession();

      if (!mounted) {
        return;
      }

      context.go(AppRoutes.driverVerificationStatus);
    } on AuthException catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.red.shade600,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _platePrefixController.dispose();
    _plateNumberController.dispose();
    _plateSuffixController.dispose();
    _vehicleModelController.dispose();
    _platePrefixFocusNode.dispose();
    _plateNumberFocusNode.dispose();
    _plateSuffixFocusNode.dispose();
    super.dispose();
  }
}

class _UpperCaseTextFormatter extends TextInputFormatter {
  const _UpperCaseTextFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
