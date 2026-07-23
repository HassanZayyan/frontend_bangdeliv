import 'package:flutter/material.dart';

import '../config/app_colors.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.name,
    this.avatarUrl,
    this.imageProvider,
    this.size = 56,
    this.borderColor,
    this.borderWidth = 0,
    this.backgroundColor,
    this.initialColor,
    this.imageScale = 1,
  });

  final String name;
  final String? avatarUrl;
  final ImageProvider? imageProvider;
  final double size;
  final Color? borderColor;
  final double borderWidth;
  final Color? backgroundColor;
  final Color? initialColor;
  final double imageScale;

  @override
  Widget build(BuildContext context) {
    final normalizedAvatarUrl = avatarUrl?.trim() ?? '';
    final normalizedName = name.trim();
    final normalizedBorderWidth = borderWidth.clamp(0, size / 2).toDouble();
    final effectiveImageScale = imageScale <= 0 ? 1.0 : imageScale;
    final effectiveBackgroundColor = backgroundColor ?? AppColors.primary;

    return Semantics(
      image: true,
      label: normalizedName.isEmpty
          ? 'Avatar pengguna'
          : 'Avatar $normalizedName',
      child: SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: effectiveBackgroundColor,
            shape: BoxShape.circle,
            border: normalizedBorderWidth > 0
                ? Border.all(
                    color: borderColor ?? AppColors.primaryDark,
                    width: normalizedBorderWidth,
                  )
                : null,
          ),
          child: Padding(
            padding: EdgeInsets.all(normalizedBorderWidth),
            child: ClipOval(
              clipBehavior: Clip.antiAlias,
              child: ColoredBox(
                color: effectiveBackgroundColor,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _ProfileAvatarInitial(
                      name: normalizedName,
                      size: size,
                      color: initialColor ?? AppColors.white,
                    ),
                    if (imageProvider != null)
                      _AvatarImage(
                        imageScale: effectiveImageScale,
                        child: Image(
                          image: imageProvider!,
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.medium,
                          gaplessPlayback: true,
                          errorBuilder: (context, error, stackTrace) {
                            return const SizedBox.shrink();
                          },
                        ),
                      )
                    else if (normalizedAvatarUrl.isNotEmpty)
                      _AvatarImage(
                        imageScale: effectiveImageScale,
                        child: Image.network(
                          normalizedAvatarUrl,
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.medium,
                          gaplessPlayback: true,
                          errorBuilder: (context, error, stackTrace) {
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AvatarImage extends StatelessWidget {
  const _AvatarImage({required this.child, required this.imageScale});

  final Widget child;
  final double imageScale;

  @override
  Widget build(BuildContext context) {
    if (imageScale == 1) {
      return child;
    }

    return Transform.scale(scale: imageScale, child: child);
  }
}

class _ProfileAvatarInitial extends StatelessWidget {
  const _ProfileAvatarInitial({
    required this.name,
    required this.size,
    required this.color,
  });

  final String name;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        _firstInitial(name),
        maxLines: 1,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontSize: size * 0.38,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }

  String _firstInitial(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return '?';
    }

    return normalized.characters.first.toUpperCase();
  }
}
