import 'package:flutter/material.dart';

import '../../../../config/app_colors.dart';
import '../../../../config/app_text_scaling.dart';

Future<String?> showCustomerOrderCancelSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
    ),
    builder: (sheetContext) => const CustomerOrderCancelSheet(),
  );
}

class CustomerOrderCancelSheet extends StatefulWidget {
  const CustomerOrderCancelSheet({super.key});

  @override
  State<CustomerOrderCancelSheet> createState() =>
      _CustomerOrderCancelSheetState();
}

class _CustomerOrderCancelSheetState extends State<CustomerOrderCancelSheet> {
  static const List<String> _quickReasons = [
    'Berubah pikiran',
    'Alamat salah',
    'Pesanan tidak jadi',
    'Terlalu lama',
    'Lainnya',
  ];

  late final TextEditingController _controller;
  String? _selectedReason;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _controller.addListener(_handleReasonChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleReasonChanged);
    _controller.dispose();
    super.dispose();
  }

  void _handleReasonChanged() {
    setState(() {});
  }

  String get _note => _controller.text.trim();

  bool get _isOtherReason => _selectedReason == 'Lainnya';

  bool get _canSubmit {
    final reason = _selectedReason;
    if (reason == null) {
      return false;
    }

    return _isOtherReason ? _note.isNotEmpty : true;
  }

  String _composeReason() {
    final reason = _selectedReason;
    final note = _note;

    if (reason == null) {
      return note;
    }

    if (_isOtherReason) {
      return note;
    }

    return reason;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final viewportHeight = MediaQuery.sizeOf(context).height;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: viewportHeight * 0.86),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Batalkan pesanan?',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    height: 1.18,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Pesanan akan dibatalkan setelah kamu memilih alasan.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.42,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Alasan pembatalan',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      for (var index = 0; index < _quickReasons.length; index++)
                        _CancelReasonTile(
                          label: _quickReasons[index],
                          selected: _selectedReason == _quickReasons[index],
                          showDivider: index < _quickReasons.length - 1,
                          onTap: () {
                            setState(() {
                              final reason = _quickReasons[index];
                              _selectedReason = reason;
                              if (reason != 'Lainnya') {
                                _controller.clear();
                              }
                            });
                          },
                        ),
                    ],
                  ),
                ),
                if (_isOtherReason) ...[
                  const SizedBox(height: 14),
                  TextField(
                    controller: _controller,
                    autofocus: true,
                    minLines: 2,
                    maxLines: 3,
                    textInputAction: TextInputAction.done,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Alasan lainnya',
                      hintText: 'Tulis alasan pembatalan',
                      alignLabelWithHint: true,
                      filled: true,
                      fillColor: AppColors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      labelStyle: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                      ),
                      hintStyle: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: AppTextScaling.adaptive(
                          context,
                          normal: 48,
                          large: 52,
                        ),
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Kembali',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: AppTextScaling.adaptive(
                          context,
                          normal: 48,
                          large: 52,
                        ),
                        child: ElevatedButton(
                          onPressed: _canSubmit
                              ? () =>
                                    Navigator.of(context).pop(_composeReason())
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                            disabledBackgroundColor: AppColors.surfaceAlt,
                            foregroundColor: AppColors.white,
                            disabledForegroundColor: AppColors.textMuted,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Batalkan Pesanan',
                              maxLines: 1,
                              softWrap: false,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CancelReasonTile extends StatelessWidget {
  const _CancelReasonTile({
    required this.label,
    required this.selected,
    required this.showDivider,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.border,
                      width: selected ? 5.5 : 1.4,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          const Divider(height: 1, indent: 46, color: AppColors.border),
      ],
    );
  }
}
