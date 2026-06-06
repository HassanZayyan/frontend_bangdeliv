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
  });

  final String name;
  final String? avatarUrl;
  final ImageProvider? imageProvider;
  final double size;
  final Color? borderColor;
  final double borderWidth;
  final Color? backgroundColor;
  final Color? initialColor;

  @override
  Widget build(BuildContext context) {
    final normalizedAvatarUrl = avatarUrl?.trim() ?? '';
    final normalizedName = name.trim();

    return Semantics(
      image: true,
      label: normalizedName.isEmpty
          ? 'Avatar pengguna'
          : 'Avatar $normalizedName',
      child: Container(
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: backgroundColor ?? AppColors.primary,
          shape: BoxShape.circle,
          border: borderWidth > 0
              ? Border.all(
                  color: borderColor ?? AppColors.primaryDark,
                  width: borderWidth,
                )
              : null,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _ProfileAvatarInitial(
              name: normalizedName,
              size: size,
              color: initialColor ?? AppColors.white,
            ),
            if (imageProvider != null)
              Image(
                image: imageProvider!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const SizedBox.shrink();
                },
              )
            else if (normalizedAvatarUrl.isNotEmpty)
              Image.network(
                normalizedAvatarUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const SizedBox.shrink();
                },
              ),
          ],
        ),
      ),
    );
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
