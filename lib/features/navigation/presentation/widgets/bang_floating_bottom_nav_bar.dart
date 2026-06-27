import 'package:flutter/material.dart';

import '../../../../config/app_colors.dart';
import '../../../../config/app_text_scaling.dart';

class BangFloatingNavItem {
  const BangFloatingNavItem({
    required this.icon,
    required this.label,
    this.activeIcon,
    this.badgeCount = 0,
  });

  final IconData icon;
  final IconData? activeIcon;
  final String label;
  final int badgeCount;
}

class BangFloatingBottomNavBar extends StatelessWidget {
  const BangFloatingBottomNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<BangFloatingNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  static const double scrollClearance = 120;
  static const double visualHeight = 60;
  static const double snackBarGap = 12;
  static const double _bottomMinimumPadding = 12;

  static double snackBarBottomInset(BuildContext context) {
    final systemBottomPadding = MediaQuery.paddingOf(context).bottom;
    final navBottomPadding = systemBottomPadding > _bottomMinimumPadding
        ? systemBottomPadding
        : _bottomMinimumPadding;

    return navBottomPadding + visualHeight + snackBarGap;
  }

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: AppTextScaling.clampedMediaQueryData(
        context,
        maxScaleFactor: AppTextScaling.denseComponentMaxScaleFactor,
      ),
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520, minHeight: 56),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.black.withValues(alpha: 0.10),
                    blurRadius: 18,
                    offset: const Offset(0, 7),
                  ),
                  BoxShadow(
                    color: AppColors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Material(
                color: AppColors.white,
                elevation: 0,
                shape: const StadiumBorder(
                  side: BorderSide(color: Color(0x33E5E7EB)),
                ),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  child: Row(
                    children: [
                      for (var index = 0; index < items.length; index++)
                        Expanded(
                          child: _BangFloatingNavButton(
                            item: items[index],
                            selected: index == currentIndex,
                            onTap: () => onTap(index),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BangFloatingBottomNavOverlayTheme extends StatelessWidget {
  const BangFloatingBottomNavOverlayTheme({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final snackBarTheme = theme.snackBarTheme.copyWith(
      behavior: SnackBarBehavior.floating,
      insetPadding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        BangFloatingBottomNavBar.snackBarBottomInset(context),
      ),
      shape:
          theme.snackBarTheme.shape ??
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );

    return Theme(
      data: theme.copyWith(snackBarTheme: snackBarTheme),
      child: child,
    );
  }
}

class BangFloatingBottomNavHost extends StatelessWidget {
  const BangFloatingBottomNavHost({
    super.key,
    required this.child,
    required this.navigationBar,
    this.hideNavigationBar = false,
  });

  final Widget child;
  final BangFloatingBottomNavBar navigationBar;
  final bool hideNavigationBar;

  @override
  Widget build(BuildContext context) {
    final shouldHideNavigationBar =
        hideNavigationBar || MediaQuery.viewInsetsOf(context).bottom > 0;

    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            ignoring: shouldHideNavigationBar,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              offset: shouldHideNavigationBar
                  ? const Offset(0, 1.25)
                  : Offset.zero,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOut,
                opacity: shouldHideNavigationBar ? 0 : 1,
                child: navigationBar,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BangFloatingNavButton extends StatelessWidget {
  const _BangFloatingNavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final BangFloatingNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textSecondary;
    final icon = selected ? item.activeIcon ?? item.icon : item.icon;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: Tooltip(
        message: item.label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          splashFactory: NoSplash.splashFactory,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          focusColor: Colors.transparent,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            height: 46,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: selected ? AppColors.primaryLight : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                _BangFloatingNavIcon(
                  icon: icon,
                  color: color,
                  selected: selected,
                  badgeCount: item.badgeCount,
                ),
                const SizedBox(height: 2),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: color,
                    fontSize: 10.5,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BangFloatingNavIcon extends StatelessWidget {
  const _BangFloatingNavIcon({
    required this.icon,
    required this.color,
    required this.selected,
    required this.badgeCount,
  });

  final IconData icon;
  final Color color;
  final bool selected;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final iconWidget = TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 1, end: selected ? 1.08 : 1),
      duration: const Duration(milliseconds: 190),
      curve: Curves.easeOutCubic,
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
      child: Icon(icon, color: color, size: 24),
    );

    if (badgeCount <= 0) {
      return SizedBox(width: 32, height: 26, child: Center(child: iconWidget));
    }

    final label = badgeCount > 99 ? '99+' : badgeCount.toString();

    return SizedBox(
      width: 32,
      height: 26,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Align(alignment: Alignment.center, child: iconWidget),
          Positioned(
            top: -2,
            right: 0,
            child: Container(
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.white, width: 1.5),
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
