import 'package:flutter/material.dart';

import '../../utils/currency_input_parser.dart';

Future<double?> showBangCounterAmountDialog(
  BuildContext context, {
  required String title,
  String hintText = 'Nominal tawaran',
}) async {
  final amount = await showDialog<double>(
    context: context,
    builder: (dialogContext) =>
        _BangCounterAmountDialog(title: title, hintText: hintText),
  );

  return amount != null && amount > 0 ? amount : null;
}

class _BangCounterAmountDialog extends StatefulWidget {
  const _BangCounterAmountDialog({required this.title, required this.hintText});

  final String title;
  final String hintText;

  @override
  State<_BangCounterAmountDialog> createState() =>
      _BangCounterAmountDialogState();
}

class _BangCounterAmountDialogState extends State<_BangCounterAmountDialog> {
  late final TextEditingController _controller;

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
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        autofocus: true,
        decoration: InputDecoration(
          prefixText: 'Rp ',
          hintText: widget.hintText,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () {
            final parsed = parseCurrencyInput(_controller.text);
            Navigator.of(context).pop(parsed > 0 ? parsed : null);
          },
          child: const Text('Kirim'),
        ),
      ],
    );
  }
}
