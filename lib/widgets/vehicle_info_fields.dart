import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/app_colors.dart';
import '../utils/vehicle_options.dart';
import 'bang_select_field.dart';

class VehicleInfoFields extends StatelessWidget {
  const VehicleInfoFields({
    super.key,
    required this.selectedVehicleType,
    required this.selectedVehicleBrand,
    required this.vehicleModelController,
    required this.onVehicleTypeChanged,
    required this.onVehicleBrandChanged,
    this.enabled = true,
    this.requiredFields = true,
    this.showLabels = false,
    this.filled = false,
    this.fillColor,
    this.vehicleTypeLabel = 'Jenis Motor',
    this.showIcons = false,
    this.capitalizeVehicleModel = false,
    this.labelColor,
    this.labelFontSize = 13,
    this.labelFontWeight = FontWeight.w700,
    this.labelBottomSpacing = 6,
    this.fieldSpacing = 16,
    this.borderRadius = 12,
    this.contentPadding = const EdgeInsets.symmetric(
      horizontal: 14,
      vertical: 13,
    ),
    this.isDense = true,
    this.fieldFontSize = 14,
    this.hintFontSize = 14,
  });

  final String? selectedVehicleType;
  final String? selectedVehicleBrand;
  final TextEditingController vehicleModelController;
  final ValueChanged<String?> onVehicleTypeChanged;
  final ValueChanged<String?> onVehicleBrandChanged;
  final bool enabled;
  final bool requiredFields;
  final bool showLabels;
  final bool filled;
  final Color? fillColor;
  final String vehicleTypeLabel;
  final bool showIcons;
  final bool capitalizeVehicleModel;
  final Color? labelColor;
  final double labelFontSize;
  final FontWeight labelFontWeight;
  final double labelBottomSpacing;
  final double fieldSpacing;
  final double borderRadius;
  final EdgeInsetsGeometry contentPadding;
  final bool isDense;
  final double fieldFontSize;
  final double hintFontSize;

  @override
  Widget build(BuildContext context) {
    final hasVehicleType = (selectedVehicleType ?? '').trim().isNotEmpty;
    final hasVehicleBrand = (selectedVehicleBrand ?? '').trim().isNotEmpty;
    final fieldTextStyle = _fieldTextStyle;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BangSelectField(
          fieldKey: ValueKey<String?>(
            'vehicle-type-${selectedVehicleType ?? ''}',
          ),
          label: showLabels ? vehicleTypeLabel : null,
          value: selectedVehicleType,
          hintText: 'Pilih jenis motor',
          items: vehicleTypeItems(selected: selectedVehicleType),
          enabled: enabled,
          onChanged: enabled ? onVehicleTypeChanged : null,
          validator: (value) {
            if (!requiredFields) {
              return null;
            }
            final selected = (value ?? '').trim();
            return selected.isEmpty ? 'Jenis motor wajib dipilih' : null;
          },
          fillColor: fillColor ?? AppColors.white,
          labelColor: labelColor ?? AppColors.textSecondary,
          labelFontSize: labelFontSize,
          labelFontWeight: labelFontWeight,
          labelBottomSpacing: labelBottomSpacing,
          fieldFontSize: fieldFontSize,
          hintFontSize: hintFontSize,
          borderRadius: borderRadius,
          contentPadding: contentPadding,
          selectedFontWeight: FontWeight.w600,
        ),
        if (hasVehicleType) ...[
          SizedBox(height: fieldSpacing),
          BangSelectField(
            fieldKey: ValueKey<String?>(
              'vehicle-brand-${selectedVehicleType ?? ''}-${selectedVehicleBrand ?? ''}',
            ),
            label: showLabels ? 'Merk Motor' : null,
            value: selectedVehicleBrand,
            hintText: 'Pilih merk motor',
            items: vehicleBrandItems(selected: selectedVehicleBrand),
            enabled: enabled,
            onChanged: enabled ? onVehicleBrandChanged : null,
            validator: (value) {
              if (!requiredFields) {
                return null;
              }
              final selected = (value ?? '').trim();
              return selected.isEmpty ? 'Merk motor wajib dipilih' : null;
            },
            fillColor: fillColor ?? AppColors.white,
            labelColor: labelColor ?? AppColors.textSecondary,
            labelFontSize: labelFontSize,
            labelFontWeight: labelFontWeight,
            labelBottomSpacing: labelBottomSpacing,
            fieldFontSize: fieldFontSize,
            hintFontSize: hintFontSize,
            borderRadius: borderRadius,
            contentPadding: contentPadding,
            selectedFontWeight: FontWeight.w600,
          ),
        ],
        if (hasVehicleBrand) ...[
          SizedBox(height: fieldSpacing),
          TextFormField(
            controller: vehicleModelController,
            enabled: enabled,
            textInputAction: TextInputAction.next,
            style: fieldTextStyle,
            textCapitalization: capitalizeVehicleModel
                ? TextCapitalization.characters
                : TextCapitalization.none,
            keyboardType: TextInputType.text,
            inputFormatters: capitalizeVehicleModel
                ? const [_UpperCaseTextFormatter()]
                : null,
            decoration: _decoration(
              labelText: showLabels ? 'Tipe Motor' : null,
              hintText: 'Contoh: Vario 160',
              icon: Icons.directions_bike_outlined,
            ),
            validator: (value) {
              if (!requiredFields) {
                return null;
              }

              final model = value?.trim() ?? '';
              if (model.isEmpty) {
                return 'Tipe motor wajib diisi';
              }

              return null;
            },
          ),
        ],
      ],
    );
  }

  InputDecoration _decoration({
    String? labelText,
    required String hintText,
    required IconData icon,
  }) {
    final decoration = InputDecoration(
      labelText: labelText,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      labelStyle: GoogleFonts.nunitoSans(
        color: labelColor ?? AppColors.textSecondary,
        fontSize: labelFontSize,
        fontWeight: labelFontWeight,
      ),
      hintText: hintText,
      isDense: isDense,
      prefixIcon: showIcons ? Icon(icon, color: AppColors.textSecondary) : null,
      filled: filled,
      fillColor: fillColor,
      hintStyle: _hintTextStyle,
    );

    if (!filled) {
      return decoration;
    }

    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(borderRadius),
      borderSide: const BorderSide(color: AppColors.border),
    );

    return decoration.copyWith(
      contentPadding: contentPadding,
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }

  TextStyle get _fieldTextStyle => GoogleFonts.nunitoSans(
    color: AppColors.textPrimary,
    fontSize: fieldFontSize,
    fontWeight: FontWeight.w400,
  );

  TextStyle get _hintTextStyle => GoogleFonts.nunitoSans(
    color: AppColors.textSecondary,
    fontSize: hintFontSize,
    fontWeight: FontWeight.w400,
  );
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
