import 'package:flutter/material.dart';

import '../../../../config/app_colors.dart';
import '../../../../config/app_text_scaling.dart';
import '../../../../models/chatbot_launch_args.dart';

class ChatbotMenuSelector extends StatefulWidget {
  const ChatbotMenuSelector({
    super.key,
    required this.merchantName,
    required this.menus,
    required this.onConfirm,
  });

  final String merchantName;
  final List<ChatbotMenuSuggestion> menus;
  final ValueChanged<String> onConfirm;

  @override
  State<ChatbotMenuSelector> createState() => _ChatbotMenuSelectorState();
}

class _ChatbotMenuSelectorState extends State<ChatbotMenuSelector> {
  late List<int> _quantities;

  @override
  void initState() {
    super.initState();
    _quantities = List<int>.filled(widget.menus.length, 0);
  }

  @override
  void didUpdateWidget(covariant ChatbotMenuSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.menus.length != widget.menus.length ||
        !_hasSameMenuNames(oldWidget.menus, widget.menus)) {
      _quantities = List<int>.filled(widget.menus.length, 0);
    }
  }

  bool get _hasSelectedItems => _quantities.any((quantity) => quantity > 0);

  bool _hasSameMenuNames(
    List<ChatbotMenuSuggestion> oldMenus,
    List<ChatbotMenuSuggestion> newMenus,
  ) {
    if (oldMenus.length != newMenus.length) {
      return false;
    }

    for (var index = 0; index < oldMenus.length; index++) {
      if (oldMenus[index].name != newMenus[index].name) {
        return false;
      }
    }

    return true;
  }

  void _setQuantity(int index, int quantity) {
    final boundedQuantity = quantity.clamp(0, 99);
    setState(() => _quantities[index] = boundedQuantity);
  }

  void _confirmSelection() {
    final lines = <String>[];
    for (var index = 0; index < widget.menus.length; index++) {
      final quantity = _quantities[index];
      if (quantity <= 0) {
        continue;
      }

      lines.add('${widget.menus[index].name.trim()} $quantity');
    }

    if (lines.isEmpty) {
      return;
    }

    widget.onConfirm(lines.join('\n'));
  }

  @override
  Widget build(BuildContext context) {
    final merchantName = widget.merchantName.trim().isEmpty
        ? 'merchant ini'
        : widget.merchantName.trim();

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Pilih menu',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: AppTextScaling.adaptive(
                    context,
                    normal: 15,
                    large: 14.4,
                  ),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                merchantName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: AppTextScaling.adaptive(
                    context,
                    normal: 12,
                    large: 11.6,
                  ),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              for (var index = 0; index < widget.menus.length; index++) ...[
                _MenuSelectorRow(
                  menu: widget.menus[index],
                  quantity: _quantities[index],
                  onDecrease: () => _setQuantity(index, _quantities[index] - 1),
                  onIncrease: () => _setQuantity(index, _quantities[index] + 1),
                ),
                if (index != widget.menus.length - 1)
                  const Divider(height: 18, color: AppColors.border),
              ],
              const SizedBox(height: 14),
              SizedBox(
                height: 46,
                child: ElevatedButton(
                  onPressed: _hasSelectedItems ? _confirmSelection : null,
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.primary.withValues(
                      alpha: 0.35,
                    ),
                    foregroundColor: AppColors.white,
                    disabledForegroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Konfirmasi',
                    style: TextStyle(
                      fontSize: AppTextScaling.adaptive(
                        context,
                        normal: 14,
                        large: 13.5,
                      ),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuSelectorRow extends StatelessWidget {
  const _MenuSelectorRow({
    required this.menu,
    required this.quantity,
    required this.onDecrease,
    required this.onIncrease,
  });

  final ChatbotMenuSuggestion menu;
  final int quantity;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    final priceLabel = (menu.priceLabel ?? '').trim();
    final imageUrl = (menu.imageUrl ?? '').trim();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 48,
            height: 48,
            color: AppColors.primaryLight,
            child: imageUrl.isEmpty
                ? const Icon(
                    Icons.restaurant_menu,
                    color: AppColors.primary,
                    size: 22,
                  )
                : Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.restaurant_menu,
                        color: AppColors.primary,
                        size: 22,
                      );
                    },
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                menu.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: AppTextScaling.adaptive(
                    context,
                    normal: 13,
                    large: 12.4,
                  ),
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (priceLabel.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  priceLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: AppTextScaling.adaptive(
                      context,
                      normal: 12,
                      large: 11.4,
                    ),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        _QuantityStepper(
          label: menu.name,
          quantity: quantity,
          onDecrease: onDecrease,
          onIncrease: onIncrease,
        ),
      ],
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.label,
    required this.quantity,
    required this.onDecrease,
    required this.onIncrease,
  });

  final String label;
  final int quantity;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepperButton(
          tooltip: 'Kurangi $label',
          icon: Icons.remove,
          enabled: quantity > 0,
          onTap: onDecrease,
        ),
        SizedBox(
          width: 28,
          child: Text(
            quantity.toString(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: AppTextScaling.adaptive(
                context,
                normal: 13,
                large: 12.4,
              ),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        _StepperButton(
          tooltip: 'Tambah $label',
          icon: Icons.add,
          enabled: quantity < 99,
          onTap: onIncrease,
        ),
      ],
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.tooltip,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? AppColors.primary : AppColors.textSecondary;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: enabled ? onTap : null,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: enabled
                ? AppColors.primaryLight
                : AppColors.border.withValues(alpha: 0.55),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}
