import 'package:flutter/material.dart';

import '../../../../config/app_colors.dart';
import '../../../../config/app_text_scaling.dart';
import '../../../../models/chatbot_launch_args.dart';
import '../../../../utils/currency_formatter.dart';
import '../../../../widgets/bang_ui.dart';
import '../../../../widgets/menu_item_row.dart';

const double _chatbotButtonRadius = 10;

class ChatbotMenuSelector extends StatefulWidget {
  const ChatbotMenuSelector({
    super.key,
    required this.merchantName,
    required this.menus,
    required this.quantities,
    required this.onQuantityDelta,
    required this.onChangeMerchant,
  });

  final String merchantName;
  final List<ChatbotMenuSuggestion> menus;
  final List<int> quantities;
  final void Function(int index, int delta) onQuantityDelta;
  final VoidCallback onChangeMerchant;

  @override
  State<ChatbotMenuSelector> createState() => _ChatbotMenuSelectorState();
}

class _ChatbotMenuSelectorState extends State<ChatbotMenuSelector> {
  /// Jumlah baris menu yang tampil sebelum tombol "Tampilkan ... lainnya".
  static const int _defaultVisibleCount = 10;

  final TextEditingController _searchController = TextEditingController();
  bool _showAll = false;

  List<int> get _quantities => List<int>.generate(
    widget.menus.length,
    (index) => index < widget.quantities.length
        ? widget.quantities[index].clamp(0, 99).toInt()
        : 0,
    growable: false,
  );

  bool get _searchEnabled => widget.menus.length > _defaultVisibleCount;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
  }

  @override
  void didUpdateWidget(covariant ChatbotMenuSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.merchantName != widget.merchantName ||
        !_hasSameMenuNames(oldWidget.menus, widget.menus)) {
      _showAll = false;
      _searchController.clear();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  bool _hasSameMenuNames(
    List<ChatbotMenuSuggestion> previous,
    List<ChatbotMenuSuggestion> next,
  ) {
    if (previous.length != next.length) {
      return false;
    }
    for (var index = 0; index < previous.length; index++) {
      if (previous[index].name != next[index].name) {
        return false;
      }
    }
    return true;
  }

  /// Indeks item (ke list menu PENUH) yang sedang tampil — qty stepper dan
  /// draft di provider selalu memakai indeks asli, bukan indeks tampilan.
  List<int> _visibleOriginalIndices() {
    final query = _searchController.text.trim().toLowerCase();
    final matches = <int>[
      for (var index = 0; index < widget.menus.length; index++)
        if (query.isEmpty ||
            widget.menus[index].name.toLowerCase().contains(query))
          index,
    ];

    if (query.isNotEmpty || _showAll || !_searchEnabled) {
      return matches;
    }

    return matches.take(_defaultVisibleCount).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final merchantName = widget.merchantName.trim().isEmpty
        ? 'tempat ini'
        : widget.merchantName.trim();
    final quantities = _quantities;
    final visibleIndices = _visibleOriginalIndices();
    final query = _searchController.text.trim();
    final hiddenCount = _searchEnabled && query.isEmpty && !_showAll
        ? widget.menus.length - visibleIndices.length
        : 0;

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
              if (_searchEnabled) ...[
                BangSearchField(
                  controller: _searchController,
                  hintText: 'Cari menu...',
                ),
                const SizedBox(height: 12),
              ],
              if (query.isNotEmpty && visibleIndices.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Menu tidak ditemukan. Coba kata lain atau tulis item manual.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: AppTextScaling.adaptive(
                        context,
                        normal: 12.5,
                        large: 12,
                      ),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              for (var order = 0; order < visibleIndices.length; order++) ...[
                _MenuSelectorRow(
                  menu: widget.menus[visibleIndices[order]],
                  quantity: quantities[visibleIndices[order]],
                  onDecrease: () =>
                      widget.onQuantityDelta(visibleIndices[order], -1),
                  onIncrease: () =>
                      widget.onQuantityDelta(visibleIndices[order], 1),
                ),
                if (order != visibleIndices.length - 1)
                  const Divider(height: 18, color: AppColors.border),
              ],
              if (hiddenCount > 0) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => setState(() => _showAll = true),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                  label: Text(
                    'Tampilkan $hiddenCount menu lainnya',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: AppTextScaling.adaptive(
                        context,
                        normal: 12.5,
                        large: 12,
                      ),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryDark,
                    side: const BorderSide(color: AppColors.border),
                    minimumSize: const Size(0, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_chatbotButtonRadius),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 4),
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

    return MenuItemRow(
      name: menu.name,
      priceLabel: priceLabel,
      pendingPrice: priceLabel == shoppingPendingPriceLabel,
      imageUrl: menu.imageUrl,
      maxNameLines: 2,
      stackedMaxNameLines: 3,
      stackTrailingOnNarrow: true,
      trailing: _QuantityStepper(
        label: menu.name,
        quantity: quantity,
        onDecrease: onDecrease,
        onIncrease: onIncrease,
      ),
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

class ChatbotMenuSelectionActionBar extends StatelessWidget {
  const ChatbotMenuSelectionActionBar({
    super.key,
    required this.selectedCount,
    required this.isSending,
    required this.onWriteManual,
    required this.onConfirm,
  });

  final int selectedCount;
  final bool isSending;
  final VoidCallback onWriteManual;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final canConfirm = selectedCount > 0 && !isSending;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.shopping_bag_outlined,
                  color: AppColors.primaryDark,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$selectedCount item dipilih',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Text(
                  'Selesaikan pilihan menu',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  flex: 4,
                  child: OutlinedButton(
                    onPressed: isSending ? null : onWriteManual,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryDark,
                      side: const BorderSide(color: AppColors.primary),
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          _chatbotButtonRadius,
                        ),
                      ),
                    ),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Tulis item manual',
                        maxLines: 1,
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 6,
                  child: FilledButton(
                    onPressed: canConfirm ? onConfirm : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.white,
                      disabledBackgroundColor: AppColors.primary.withValues(
                        alpha: 0.34,
                      ),
                      disabledForegroundColor: AppColors.white,
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          _chatbotButtonRadius,
                        ),
                      ),
                    ),
                    child: isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.white,
                            ),
                          )
                        : FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Konfirmasi Pilihan ($selectedCount)',
                              maxLines: 1,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
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
    );
  }
}

class ChatbotMenuSelectionLoadingBar extends StatelessWidget {
  const ChatbotMenuSelectionLoadingBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: const SafeArea(
        top: false,
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Memuat menu tempat...',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatbotMenuSelectorInfoBubble extends StatelessWidget {
  const ChatbotMenuSelectorInfoBubble({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
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
          child: child,
        ),
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
