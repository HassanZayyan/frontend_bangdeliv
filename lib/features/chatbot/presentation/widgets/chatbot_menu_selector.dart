import 'package:flutter/material.dart';

import '../../../../config/app_colors.dart';
import '../../../../config/app_text_scaling.dart';
import '../../../../models/chatbot_launch_args.dart';

const double _chatbotButtonRadius = 10;

class ChatbotMenuSelector extends StatefulWidget {
  const ChatbotMenuSelector({
    super.key,
    required this.merchantName,
    required this.menus,
    required this.quantities,
    required this.onQuantityDelta,
    required this.onChangeMerchant,
    required this.onConfirm,
  });

  final String merchantName;
  final List<ChatbotMenuSuggestion> menus;
  final List<int> quantities;
  final void Function(int index, int delta) onQuantityDelta;
  final VoidCallback onChangeMerchant;
  final ValueChanged<String> onConfirm;

  @override
  State<ChatbotMenuSelector> createState() => _ChatbotMenuSelectorState();
}

class _ChatbotMenuSelectorState extends State<ChatbotMenuSelector> {
  List<int> get _quantities => List<int>.generate(
    widget.menus.length,
    (index) => index < widget.quantities.length
        ? widget.quantities[index].clamp(0, 99).toInt()
        : 0,
    growable: false,
  );

  bool get _hasSelectedItems => _quantities.any((quantity) => quantity > 0);

  void _confirmSelection() {
    final quantities = _quantities;
    final lines = <String>[];
    for (var index = 0; index < widget.menus.length; index++) {
      final quantity = quantities[index];
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
        ? 'tempat ini'
        : widget.merchantName.trim();
    final quantities = _quantities;

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
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _MenuSelectorHeader(
                merchantName,
                onChangeMerchant: widget.onChangeMerchant,
              ),
              const SizedBox(height: 12),
              for (var index = 0; index < widget.menus.length; index++) ...[
                _MenuSelectorRow(
                  menu: widget.menus[index],
                  quantity: quantities[index],
                  onDecrease: () => widget.onQuantityDelta(index, -1),
                  onIncrease: () => widget.onQuantityDelta(index, 1),
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
                      borderRadius: BorderRadius.circular(_chatbotButtonRadius),
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

class _MenuSelectorHeader extends StatelessWidget {
  const _MenuSelectorHeader(
    this.merchantName, {
    required this.onChangeMerchant,
  });

  final String merchantName;
  final VoidCallback onChangeMerchant;

  @override
  Widget build(BuildContext context) {
    final title = Text(
      'Pilih menu',
      style: TextStyle(
        color: AppColors.textPrimary,
        fontSize: AppTextScaling.adaptive(context, normal: 15, large: 14.4),
        fontWeight: FontWeight.w800,
      ),
    );
    final merchant = Text(
      merchantName,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: AppColors.textSecondary,
        fontSize: AppTextScaling.adaptive(context, normal: 12, large: 11.6),
        fontWeight: FontWeight.w600,
      ),
    );
    final changeButton = OutlinedButton.icon(
      onPressed: onChangeMerchant,
      icon: Icon(
        Icons.storefront_outlined,
        size: AppTextScaling.adaptive(context, normal: 16, large: 15),
      ),
      label: Text(
        'Ganti Toko/Resto',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: AppTextScaling.adaptive(context, normal: 12, large: 11.5),
          fontWeight: FontWeight.w700,
        ),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryDark,
        minimumSize: const Size(0, 32),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        side: const BorderSide(color: AppColors.primary, width: 1.2),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_chatbotButtonRadius),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        title,
        const SizedBox(height: 4),
        merchant,
        const SizedBox(height: 8),
        Align(alignment: Alignment.centerLeft, child: changeButton),
      ],
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final useStackedControls = constraints.maxWidth < 340;
        final hasThumbnail = imageUrl.isNotEmpty;
        final thumbnail = hasThumbnail
            ? _MenuThumbnail(imageUrl: imageUrl)
            : null;
        final details = _MenuDetails(
          menuName: menu.name,
          priceLabel: priceLabel,
          maxNameLines: useStackedControls ? 3 : 2,
        );
        final stepper = _QuantityStepper(
          label: menu.name,
          quantity: quantity,
          onDecrease: onDecrease,
          onIncrease: onIncrease,
        );

        if (useStackedControls) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (thumbnail != null) ...[thumbnail, const SizedBox(width: 12)],
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    details,
                    const SizedBox(height: 10),
                    Align(alignment: Alignment.centerRight, child: stepper),
                  ],
                ),
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (thumbnail != null) ...[thumbnail, const SizedBox(width: 12)],
            Expanded(child: details),
            const SizedBox(width: 10),
            stepper,
          ],
        );
      },
    );
  }
}

class _MenuThumbnail extends StatelessWidget {
  const _MenuThumbnail({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 48,
        height: 48,
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}

class _MenuDetails extends StatelessWidget {
  const _MenuDetails({
    required this.menuName,
    required this.priceLabel,
    required this.maxNameLines,
  });

  final String menuName;
  final String priceLabel;
  final int maxNameLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          menuName,
          maxLines: maxNameLines,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: AppTextScaling.adaptive(context, normal: 13, large: 12.4),
            fontWeight: FontWeight.w800,
            height: 1.24,
          ),
        ),
        if (priceLabel.isNotEmpty) ...[
          const SizedBox(height: 4),
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
    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(_chatbotButtonRadius),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepperButton(
            tooltip: 'Kurangi $label',
            icon: Icons.remove_rounded,
            enabled: quantity > 0,
            foregroundColor: quantity > 0
                ? AppColors.textPrimary
                : AppColors.textSecondary.withValues(alpha: 0.42),
            onTap: onDecrease,
          ),
          SizedBox(
            width: 30,
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
            icon: Icons.add_rounded,
            enabled: quantity < 99,
            foregroundColor: quantity < 99
                ? AppColors.primary
                : AppColors.textSecondary.withValues(alpha: 0.42),
            onTap: onIncrease,
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.tooltip,
    required this.icon,
    required this.enabled,
    required this.foregroundColor,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final bool enabled;
  final Color foregroundColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: SizedBox(
            width: 31,
            height: 34,
            child: Icon(icon, size: 18, color: foregroundColor),
          ),
        ),
      ),
    );
  }
}
