import 'package:flutter/material.dart';

import '../../config/app_colors.dart';
import '../../utils/currency_input_parser.dart';
import '../../utils/order_formatters.dart';

Future<double?> showBangCounterAmountDialog(
  BuildContext context, {
  required String title,
  double? currentAmount,
  String hintText = 'Nominal tawaran',
}) async {
  final amount = await showModalBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
    ),
    builder: (dialogContext) => _BangCounterAmountSheet(
      title: title,
      hintText: hintText,
      currentAmount: currentAmount,
    ),
  );

  return amount != null && amount > 0 ? amount : null;
}

class _BangCounterAmountSheet extends StatefulWidget {
  const _BangCounterAmountSheet({
    required this.title,
    required this.hintText,
    this.currentAmount,
  });

  final String title;
  final String hintText;
  final double? currentAmount;

  @override
  State<_BangCounterAmountSheet> createState() =>
      _BangCounterAmountSheetState();
}

class _BangCounterAmountSheetState extends State<_BangCounterAmountSheet> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);

    return SafeArea(
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.fromLTRB(18, 18, 18, viewInsets.bottom + 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Text(
              widget.title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            if ((widget.currentAmount ?? 0) > 0) ...[
              const SizedBox(height: 8),
              Text(
                'Harga saat ini ${formatCurrency(widget.currentAmount!)}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                labelText: widget.hintText,
                prefixText: 'Rp ',
                errorText: _errorText,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _submit,
                    child: const Text('Kirim'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    final parsed = parseCurrencyInput(_controller.text);
    if (parsed <= 0) {
      setState(() => _errorText = 'Nominal tawaran wajib lebih dari 0.');
      return;
    }

    Navigator.of(context).pop(parsed);
  }
}
