import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/app_colors.dart';
import '../config/app_text_scaling.dart';

class BangSelectField extends StatelessWidget {
  const BangSelectField({
    super.key,
    this.fieldKey,
    this.label,
    required this.value,
    required this.hintText,
    required this.items,
    required this.onChanged,
    this.validator,
    this.enabled = true,
    this.fillColor = AppColors.white,
    this.labelColor = AppColors.textSecondary,
    this.labelFontSize = 12,
    this.labelFontWeight = FontWeight.w600,
    this.labelBottomSpacing = 4,
    this.fieldFontSize = 14,
    this.hintFontSize = 14,
    this.borderRadius = 10,
    this.contentPadding = const EdgeInsets.symmetric(
      horizontal: 14,
      vertical: 13,
    ),
    this.menuMaxHeight = 300,
    this.selectedFontWeight = FontWeight.w600,
    this.hintFontWeight = FontWeight.w500,
  });

  final Key? fieldKey;
  final String? label;
  final String? value;
  final String hintText;
  final List<String> items;
  final ValueChanged<String?>? onChanged;
  final FormFieldValidator<String>? validator;
  final bool enabled;
  final Color fillColor;
  final Color labelColor;
  final double labelFontSize;
  final FontWeight labelFontWeight;
  final double labelBottomSpacing;
  final double fieldFontSize;
  final double hintFontSize;
  final double borderRadius;
  final EdgeInsetsGeometry contentPadding;
  final double menuMaxHeight;
  final FontWeight selectedFontWeight;
  final FontWeight hintFontWeight;

  @override
  Widget build(BuildContext context) {
    final effectiveLabelFontSize = AppTextScaling.adaptive(
      context,
      normal: labelFontSize,
      large: labelFontSize - 0.4,
    );
    final effectiveFieldFontSize = AppTextScaling.adaptive(
      context,
      normal: fieldFontSize,
      large: fieldFontSize - 0.7,
    );
    final effectiveHintFontSize = AppTextScaling.adaptive(
      context,
      normal: hintFontSize,
      large: hintFontSize - 0.7,
    );

    return FormField<String>(
      key: fieldKey,
      initialValue: value,
      validator: validator,
      builder: (field) {
        final selectedValue = (value ?? field.value ?? '').trim();
        final hasValue = selectedValue.isNotEmpty;
        final isInteractive = enabled && onChanged != null && items.isNotEmpty;
        final errorText = field.errorText;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Builder(
              builder: (fieldContext) {
                return InkWell(
                  borderRadius: BorderRadius.circular(borderRadius),
                  onTap: !isInteractive
                      ? null
                      : () async {
                          await _scrollIntoView(fieldContext);
                          if (!fieldContext.mounted) return;

                          final pickedValue = await _showOptionsMenu(
                            context: context,
                            fieldContext: fieldContext,
                            selectedValue: selectedValue,
                            itemFontSize: effectiveFieldFontSize,
                          );
                          if (pickedValue == null) return;

                          field.didChange(pickedValue);
                          onChanged?.call(pickedValue);
                        },
                  child: InputDecorator(
                    isEmpty: !hasValue,
                    decoration: _decoration(
                      errorText: errorText,
                      labelFontSize: effectiveLabelFontSize,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            hasValue ? selectedValue : hintText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: hasValue
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                              fontSize: hasValue
                                  ? effectiveFieldFontSize
                                  : effectiveHintFontSize,
                              fontWeight: hasValue
                                  ? selectedFontWeight
                                  : hintFontWeight,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 22,
                          color: isInteractive
                              ? AppColors.textSecondary
                              : AppColors.textSecondary.withValues(alpha: 0.55),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  InputDecoration _decoration({
    String? errorText,
    required double labelFontSize,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(borderRadius),
      borderSide: const BorderSide(color: AppColors.border),
    );
    final errorBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(borderRadius),
      borderSide: const BorderSide(color: AppColors.error),
    );

    return InputDecoration(
      isDense: true,
      contentPadding: contentPadding,
      filled: true,
      fillColor: fillColor,
      labelText: (label ?? '').trim().isEmpty ? null : label!.trim(),
      floatingLabelBehavior: FloatingLabelBehavior.always,
      labelStyle: GoogleFonts.inter(
        color: labelColor,
        fontSize: labelFontSize,
        fontWeight: labelFontWeight,
      ),
      errorText: errorText,
      border: border,
      enabledBorder: border,
      disabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: errorBorder,
      focusedErrorBorder: errorBorder,
      errorStyle: GoogleFonts.inter(
        color: AppColors.error,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Future<void> _scrollIntoView(BuildContext fieldContext) async {
    await Scrollable.ensureVisible(
      fieldContext,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      alignment: 0.12,
      alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
    );
  }

  Future<String?> _showOptionsMenu({
    required BuildContext context,
    required BuildContext fieldContext,
    required String selectedValue,
    required double itemFontSize,
  }) {
    final overlayRenderObject = Overlay.of(context).context.findRenderObject();
    final fieldRenderObject = fieldContext.findRenderObject();

    if (overlayRenderObject is! RenderBox || fieldRenderObject is! RenderBox) {
      return Future.value(null);
    }

    final fieldWidth = fieldRenderObject.size.width;
    final fieldTopLeft = fieldRenderObject.localToGlobal(
      Offset.zero,
      ancestor: overlayRenderObject,
    );
    final fieldBottomRight = fieldRenderObject.localToGlobal(
      fieldRenderObject.size.bottomRight(Offset.zero),
      ancestor: overlayRenderObject,
    );
    final position = RelativeRect.fromLTRB(
      fieldTopLeft.dx,
      fieldBottomRight.dy + 4,
      overlayRenderObject.size.width - fieldBottomRight.dx,
      overlayRenderObject.size.height - fieldBottomRight.dy,
    );

    return showMenu<String>(
      context: context,
      position: position,
      color: AppColors.white,
      surfaceTintColor: AppColors.white,
      shadowColor: Colors.black26,
      constraints: BoxConstraints(
        minWidth: fieldWidth,
        maxWidth: fieldWidth,
        maxHeight: menuMaxHeight,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      items: items
          .map(
            (item) => PopupMenuItem<String>(
              value: item,
              height: AppTextScaling.adaptive(context, normal: 44, large: 48),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: _BangSelectMenuItem(
                text: item,
                selected: item == selectedValue,
                fontSize: itemFontSize,
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _BangSelectMenuItem extends StatelessWidget {
  const _BangSelectMenuItem({
    required this.text,
    required this.selected,
    required this.fontSize,
  });

  final String text;
  final bool selected;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: AppColors.textPrimary,
              fontSize: fontSize,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
        if (selected) ...[
          const SizedBox(width: 10),
          const Icon(Icons.check_rounded, size: 18, color: AppColors.primary),
        ],
      ],
    );
  }
}
