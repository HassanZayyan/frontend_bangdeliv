import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../utils/vehicle_options.dart';

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

  @override
  Widget build(BuildContext context) {
    final hasVehicleType = (selectedVehicleType ?? '').trim().isNotEmpty;
    final hasVehicleBrand = (selectedVehicleBrand ?? '').trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('Jenis Motor'),
        DropdownButtonFormField<String>(
          key: ValueKey<String?>('vehicle-type-${selectedVehicleType ?? ''}'),
          initialValue: selectedVehicleType,
          isExpanded: true,
          decoration: _decoration(
            hintText: 'Pilih jenis motor',
            icon: Icons.two_wheeler_outlined,
          ),
          items: vehicleTypeItems(selected: selectedVehicleType)
              .map(
                (type) =>
                    DropdownMenuItem<String>(value: type, child: Text(type)),
              )
              .toList(growable: false),
          onChanged: enabled ? onVehicleTypeChanged : null,
          validator: (value) {
            if (!requiredFields) {
              return null;
            }

            final selected = (value ?? '').trim();
            if (selected.isEmpty) {
              return 'Jenis motor wajib dipilih';
            }

            return null;
          },
        ),
        if (hasVehicleType) ...[
          const SizedBox(height: 16),
          _buildFieldLabel('Merk Motor'),
          DropdownButtonFormField<String>(
            key: ValueKey<String?>(
              'vehicle-brand-${selectedVehicleBrand ?? ''}',
            ),
            initialValue: selectedVehicleBrand,
            isExpanded: true,
            decoration: _decoration(
              hintText: 'Pilih merk motor',
              icon: Icons.local_offer_outlined,
            ),
            items: vehicleBrandItems(selected: selectedVehicleBrand)
                .map(
                  (brand) => DropdownMenuItem<String>(
                    value: brand,
                    child: Text(brand),
                  ),
                )
                .toList(growable: false),
            onChanged: enabled ? onVehicleBrandChanged : null,
            validator: (value) {
              if (!requiredFields) {
                return null;
              }

              final selected = (value ?? '').trim();
              if (selected.isEmpty) {
                return 'Merk motor wajib dipilih';
              }

              return null;
            },
          ),
        ],
        if (hasVehicleBrand) ...[
          const SizedBox(height: 16),
          _buildFieldLabel('Tipe Motor'),
          TextFormField(
            controller: vehicleModelController,
            enabled: enabled,
            textInputAction: TextInputAction.next,
            keyboardType: TextInputType.text,
            decoration: _decoration(
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

  Widget _buildFieldLabel(String text) {
    if (!showLabels) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  InputDecoration _decoration({
    required String hintText,
    required IconData icon,
  }) {
    final decoration = InputDecoration(
      hintText: hintText,
      prefixIcon: Icon(icon, color: AppColors.textSecondary),
      filled: filled,
      fillColor: fillColor,
    );

    if (!filled) {
      return decoration;
    }

    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.border),
    );

    return decoration.copyWith(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: border,
      enabledBorder: border,
    );
  }
}
