import 'package:flutter/material.dart';

import '../../config/app_colors.dart';

class BangUnavailableItemChoice {
  const BangUnavailableItemChoice({
    required this.id,
    required this.label,
    this.subtitle = 'Tidak tersedia',
  });

  final int id;
  final String label;
  final String subtitle;
}

Future<List<int>?> showBangUnavailableItemPicker(
  BuildContext context, {
  required List<BangUnavailableItemChoice> items,
  String title = 'Pilih item yang dilewati',
}) {
  return showModalBottomSheet<List<int>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) =>
        _BangUnavailableItemPicker(items: items, title: title),
  );
}

class _BangUnavailableItemPicker extends StatefulWidget {
  const _BangUnavailableItemPicker({required this.items, required this.title});

  final List<BangUnavailableItemChoice> items;
  final String title;

  @override
  State<_BangUnavailableItemPicker> createState() =>
      _BangUnavailableItemPickerState();
}

class _BangUnavailableItemPickerState
    extends State<_BangUnavailableItemPicker> {
  final Set<int> _selectedIds = <int>{};

  @override
  Widget build(BuildContext context) {
    final selectedCount = _selectedIds.length;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.72,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Pilih satu atau beberapa item. Item lain tetap menunggu keputusan.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.items.length,
                  itemBuilder: (context, index) {
                    final item = widget.items[index];
                    final selected = _selectedIds.contains(item.id);
                    return CheckboxListTile(
                      key: ValueKey('unavailable-item-choice-${item.id}'),
                      value: selected,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(
                        item.label,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(item.subtitle),
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _selectedIds.add(item.id);
                          } else {
                            _selectedIds.remove(item.id);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      key: const ValueKey('confirm-unavailable-item-selection'),
                      onPressed: selectedCount == 0
                          ? null
                          : () => Navigator.of(
                              context,
                            ).pop(_selectedIds.toList(growable: false)),
                      child: Text(
                        selectedCount == 0
                            ? 'Pilih item'
                            : 'Lanjut tanpa $selectedCount item',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
