import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../config/app_text_scaling.dart';

class BangScaffold extends StatelessWidget {
  const BangScaffold({
    super.key,
    required this.body,
    this.title,
    this.actions,
    this.bottomNavigationBar,
    this.leading,
    this.safeBottom = false,
  });

  final Widget body;
  final String? title;
  final List<Widget>? actions;
  final Widget? bottomNavigationBar;
  final Widget? leading;
  final bool safeBottom;

  @override
  Widget build(BuildContext context) {
    final appBarTitle = title == null
        ? null
        : Text(title!, maxLines: 1, overflow: TextOverflow.ellipsis);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: title == null
          ? null
          : AppBar(title: appBarTitle, actions: actions, leading: leading),
      body: SafeArea(bottom: safeBottom, child: body),
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}

class BangCard extends StatelessWidget {
  const BangCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.borderColor = AppColors.border,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class BangSectionHeader extends StatelessWidget {
  const BangSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final titleFontSize = AppTextScaling.adaptive(
      context,
      normal: 18,
      large: 17,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: titleFontSize,
                height: 1.08,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.only(left: 8, right: 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                alignment: Alignment.centerRight,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  AppTextScaling.clampForCompactComponent(
                    context: context,
                    maxScaleFactor: AppTextScaling.denseComponentMaxScaleFactor,
                    child: Text(
                      actionLabel!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 1),
                  const Icon(Icons.chevron_right_rounded, size: 14),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class BangStatusChip extends StatelessWidget {
  const BangStatusChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.showIcon = true,
    this.compact = false,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final bool showIcon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return AppTextScaling.clampForCompactComponent(
      context: context,
      maxScaleFactor: AppTextScaling.denseComponentMaxScaleFactor,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 9 : 10,
          vertical: compact ? 4 : 5,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: compact ? 0.08 : 0.10),
          borderRadius: BorderRadius.circular(compact ? 8 : 999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showIcon && icon != null) ...[
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: compact ? 11.5 : 11.5,
                  fontWeight: compact ? FontWeight.w700 : FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BangPrimaryButton extends StatelessWidget {
  const BangPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final child = AppTextScaling.clampForCompactComponent(
      context: context,
      child: isLoading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.white,
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (icon != null) ...[
                  const SizedBox(width: 8),
                  Icon(icon, size: 18),
                ],
              ],
            ),
    );

    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        child: child,
      ),
    );
  }
}

typedef AuthHeaderHeightBuilder =
    double Function(BuildContext context, bool isKeyboardOpen);
typedef AuthCardPaddingBuilder =
    EdgeInsets Function(BuildContext context, bool isKeyboardOpen);

class AuthKeyboardSafeScaffold extends StatelessWidget {
  const AuthKeyboardSafeScaffold({
    super.key,
    required this.header,
    required this.child,
    required this.headerHeightBuilder,
    required this.cardPaddingBuilder,
    this.topBar,
    this.topBarHeight = 0,
  });

  final Widget header;
  final Widget child;
  final AuthHeaderHeightBuilder headerHeightBuilder;
  final AuthCardPaddingBuilder cardPaddingBuilder;
  final Widget? topBar;
  final double topBarHeight;

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final isKeyboardOpen = keyboardInset > 0;
    final headerHeight = headerHeightBuilder(context, isKeyboardOpen);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: AppColors.primary,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cardMinHeight = math.max(
              0.0,
              constraints.maxHeight - topBarHeight - headerHeight,
            );

            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.only(bottom: keyboardInset),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (topBar != null)
                      SizedBox(height: topBarHeight, child: topBar),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      height: headerHeight,
                      child: ClipRect(child: header),
                    ),
                    Container(
                      width: double.infinity,
                      constraints: BoxConstraints(minHeight: cardMinHeight),
                      padding: cardPaddingBuilder(context, isKeyboardOpen),
                      decoration: const BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(30),
                          topRight: Radius.circular(30),
                        ),
                      ),
                      child: child,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class BangSearchField extends StatelessWidget {
  const BangSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    this.focusNode,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hintText;
  final FocusNode? focusNode;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final fieldFontSize = AppTextScaling.adaptive(
      context,
      normal: 14,
      large: 13.25,
    );

    return TextField(
      controller: controller,
      focusNode: focusNode,
      textInputAction: TextInputAction.search,
      onSubmitted: onSubmitted,
      style: TextStyle(
        color: AppColors.textPrimary,
        fontSize: fieldFontSize,
        fontWeight: FontWeight.w400,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: AppColors.textMuted,
          fontSize: fieldFontSize,
          fontWeight: FontWeight.w400,
        ),
        prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
      ),
    );
  }
}

class BangEmptyState extends StatelessWidget {
  const BangEmptyState({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
  });

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return BangCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.textMuted, size: 34),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class BangIllustrationEmptyState extends StatelessWidget {
  const BangIllustrationEmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    this.titleFontSize = 14.5,
    this.titleFontWeight = FontWeight.w700,
    this.titleColor = AppColors.textPrimary,
  });

  final String title;
  final String subtitle;
  final double titleFontSize;
  final FontWeight titleFontWeight;
  final Color titleColor;

  @override
  Widget build(BuildContext context) {
    final hasSubtitle = subtitle.trim().isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: AppTextScaling.adaptive(context, normal: 120, large: 106),
              height: AppTextScaling.adaptive(context, normal: 120, large: 106),
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    top: 0,
                    right: 6,
                    child: Icon(
                      Icons.description_rounded,
                      size: 96,
                      color: AppColors.border,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: AppColors.surface,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: AppColors.border,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.schedule_rounded,
                          size: 52,
                          color: AppColors.surface,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: titleFontSize,
                fontWeight: titleFontWeight,
                color: titleColor,
              ),
            ),
            if (hasSubtitle) ...[
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class BangErrorState extends StatelessWidget {
  const BangErrorState({
    super.key,
    required this.title,
    required this.message,
    this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return BangCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Coba lagi'),
            ),
          ],
        ],
      ),
    );
  }
}

class BangLoadingSkeleton extends StatelessWidget {
  const BangLoadingSkeleton({super.key, this.height = 96});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
    );
  }
}
