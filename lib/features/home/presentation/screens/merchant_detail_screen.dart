import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/app_colors.dart';
import '../../../../config/app_routes.dart';
import '../../../../config/app_text_scaling.dart';
import '../../../../core/di/app_providers.dart';
import '../../../../models/chatbot_launch_args.dart';
import '../../../../models/food_model.dart';
import '../../../../models/merchant_detail_model.dart';
import '../../../../models/merchant_model.dart';
import '../../../../widgets/menu_item_row.dart';
import '../../../auth/application/auth_session_provider.dart';
import '../../../auth/presentation/widgets/guest_login_prompt.dart';

final _merchantDetailProvider = FutureProvider.autoDispose
    .family<MerchantDetailModel, String>((ref, merchantId) {
      return ref.watch(homeApiServiceProvider).fetchMerchantDetail(merchantId);
    });

class MerchantDetailArgs {
  const MerchantDetailArgs({required this.merchant, this.returnPath});

  final MerchantModel merchant;
  final String? returnPath;
}

class MerchantDetailScreen extends ConsumerWidget {
  const MerchantDetailScreen({
    super.key,
    required this.merchantId,
    this.initialMerchant,
    this.returnPath,
  });

  final String merchantId;
  final MerchantModel? initialMerchant;
  final String? returnPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final normalizedMerchantId = merchantId.trim();
    final fallbackMerchant = initialMerchant;

    if (normalizedMerchantId.isEmpty) {
      if (fallbackMerchant != null) {
        return _MerchantDetailView(
          merchant: fallbackMerchant,
          menus: const <FoodModel>[],
          returnPath: returnPath,
          menusError: 'Menu tempat eksternal belum tersedia.',
        );
      }

      return _MerchantDetailErrorState(
        message: 'Tempat tidak valid.',
        onBack: () => _handleBack(context),
      );
    }

    final detailAsync = ref.watch(
      _merchantDetailProvider(normalizedMerchantId),
    );

    return detailAsync.when(
      loading: () {
        if (fallbackMerchant == null) {
          return _MerchantDetailLoadingState(
            onBack: () => _handleBack(context),
          );
        }

        return _MerchantDetailView(
          merchant: fallbackMerchant,
          menus: const <FoodModel>[],
          returnPath: returnPath,
          isLoadingMenus: true,
        );
      },
      error: (error, stackTrace) {
        if (fallbackMerchant != null) {
          return _MerchantDetailView(
            merchant: fallbackMerchant,
            menus: const <FoodModel>[],
            returnPath: returnPath,
            menusError: 'Menu belum bisa dimuat. Tarik untuk coba lagi.',
          );
        }

        return _MerchantDetailErrorState(
          message: 'Gagal memuat detail tempat.',
          onBack: () => _handleBack(context),
        );
      },
      data: (detail) => _MerchantDetailView(
        merchant: detail.merchant,
        menus: detail.menus,
        returnPath: returnPath,
        displayDistance: _effectiveDistance(detail.merchant, fallbackMerchant),
      ),
    );
  }

  String _effectiveDistance(
    MerchantModel merchant,
    MerchantModel? fallbackMerchant,
  ) {
    final detailDistance = merchant.distance.trim();
    if (detailDistance.isNotEmpty && detailDistance != '-') {
      return detailDistance;
    }

    final fallbackDistance = fallbackMerchant?.distance.trim() ?? '';
    if (fallbackDistance.isNotEmpty && fallbackDistance != '-') {
      return fallbackDistance;
    }

    return '';
  }

  void _handleBack(BuildContext context) {
    final target = returnPath;
    if (target != null && target.isNotEmpty) {
      context.go(target);
      return;
    }

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }

    context.go(AppRoutes.home);
  }
}

class _MerchantDetailView extends ConsumerWidget {
  const _MerchantDetailView({
    required this.merchant,
    required this.menus,
    this.returnPath,
    this.displayDistance,
    this.isLoadingMenus = false,
    this.menusError,
  });

  final MerchantModel merchant;
  final List<FoodModel> menus;
  final String? returnPath;
  final String? displayDistance;
  final bool isLoadingMenus;
  final String? menusError;

  void _handleBack(BuildContext context) {
    final target = returnPath;
    if (target != null && target.isNotEmpty) {
      context.go(target);
      return;
    }

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }

    context.go(AppRoutes.home);
  }

  void _openNitipChatbot(BuildContext context, WidgetRef ref) {
    final merchantId = int.tryParse(merchant.id.trim());
    final menuSuggestions = menus
        .map(
          (menu) => ChatbotMenuSuggestion(
            name: menu.name,
            presetMessage: '${menu.name} 1',
            priceLabel: menu.formattedPrice,
            imageUrl: menu.imageUrl,
          ),
        )
        .toList(growable: false);
    final target = Uri(
      path: AppRoutes.chatbot,
      queryParameters: const <String, String>{'service_type': 'nitip'},
    ).toString();

    final session = ref.read(authSessionProvider);
    if (isGuestSession(session)) {
      showGuestLoginPrompt(
        context,
        title: 'Masuk untuk pesan dari toko ini',
        message:
            'Detail toko dan menu bisa dilihat sebagai tamu. Untuk membuat pesanan, masuk dulu agar alamat dan status pesanan tersimpan.',
        returnTo: GoRouterState.of(context).uri.toString(),
      );
      return;
    }

    context.push(
      target,
      extra: ChatbotLaunchArgs(
        serviceType: 'nitip',
        merchantId: merchantId,
        merchantName: merchant.name,
        menuSuggestions: menuSuggestions,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopScope<void>(
      canPop: returnPath == null || returnPath!.isEmpty,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }

        _handleBack(context);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text(
            'Detail Toko & Resto',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          backgroundColor: AppColors.white,
          elevation: 0,
          leading: IconButton(
            tooltip: 'Kembali',
            icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary),
            onPressed: () => _handleBack(context),
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _openNitipChatbot(context, ref),
              icon: const Icon(Icons.sms_outlined),
              label: const Text('Pesan di chatbot'),
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MerchantHero(merchant: merchant),
              const SizedBox(height: 18),
              _MerchantInfo(
                merchant: merchant,
                menuCount: menus.length,
                displayDistance: displayDistance,
              ),
              const SizedBox(height: 22),
              _MenuSection(
                menus: menus,
                isLoading: isLoadingMenus,
                errorText: menusError,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MerchantHero extends StatefulWidget {
  const _MerchantHero({required this.merchant});

  final MerchantModel merchant;

  @override
  State<_MerchantHero> createState() => _MerchantHeroState();
}

class _MerchantHeroState extends State<_MerchantHero> {
  int _currentIndex = 0;

  List<String> get _imageUrls {
    final gallery = widget.merchant.galleryImageUrls
        .where((url) => url.trim().isNotEmpty)
        .toList(growable: false);
    if (gallery.isNotEmpty) {
      return gallery;
    }

    final fallback = widget.merchant.imageUrl.trim();
    return fallback.isEmpty ? const <String>[] : <String>[fallback];
  }

  @override
  Widget build(BuildContext context) {
    final imageUrls = _imageUrls;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: imageUrls.isEmpty
            ? const _MerchantHeroFallback(icon: Icons.storefront_outlined)
            : Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    itemCount: imageUrls.length,
                    onPageChanged: (index) {
                      if (!mounted) {
                        return;
                      }

                      setState(() => _currentIndex = index);
                    },
                    itemBuilder: (context, index) {
                      return Semantics(
                        label:
                            'Foto ${widget.merchant.name} ${index + 1} dari ${imageUrls.length}',
                        button: true,
                        image: true,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _openPhotoPreview(
                            context,
                            imageUrls: imageUrls,
                            initialIndex: index,
                            merchantName: widget.merchant.name,
                          ),
                          child: _MerchantHeroImage(imageUrl: imageUrls[index]),
                        ),
                      );
                    },
                  ),
                  if (imageUrls.length > 1)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 10,
                      child: Center(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.black.withValues(alpha: 0.28),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 5,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (
                                  var index = 0;
                                  index < imageUrls.length;
                                  index++
                                )
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    curve: Curves.easeOut,
                                    width: index == _currentIndex ? 18 : 6,
                                    height: 6,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: index == _currentIndex
                                          ? AppColors.white
                                          : AppColors.white.withValues(
                                              alpha: 0.58,
                                            ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  void _openPhotoPreview(
    BuildContext context, {
    required List<String> imageUrls,
    required int initialIndex,
    required String merchantName,
  }) {
    if (imageUrls.isEmpty) {
      return;
    }

    showDialog<void>(
      context: context,
      barrierColor: AppColors.black,
      builder: (context) {
        return _MerchantPhotoPreview(
          imageUrls: imageUrls,
          initialIndex: initialIndex,
          merchantName: merchantName,
        );
      },
    );
  }
}

class _MerchantPhotoPreview extends StatefulWidget {
  const _MerchantPhotoPreview({
    required this.imageUrls,
    required this.initialIndex,
    required this.merchantName,
  });

  final List<String> imageUrls;
  final int initialIndex;
  final String merchantName;

  @override
  State<_MerchantPhotoPreview> createState() => _MerchantPhotoPreviewState();
}

class _MerchantPhotoPreviewState extends State<_MerchantPhotoPreview>
    with SingleTickerProviderStateMixin {
  static const double _doubleTapZoomScale = 2.6;

  late final PageController _pageController;
  late final TransformationController _transformationController;
  late final AnimationController _zoomAnimationController;
  Animation<Matrix4>? _zoomAnimation;
  late int _currentIndex;
  Offset? _doubleTapLocalPosition;

  @override
  void initState() {
    super.initState();
    final maxIndex = widget.imageUrls.isEmpty ? 0 : widget.imageUrls.length - 1;
    _currentIndex = widget.initialIndex.clamp(0, maxIndex).toInt();
    _pageController = PageController(initialPage: _currentIndex);
    _transformationController = TransformationController();
    _zoomAnimationController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 190),
        )..addListener(() {
          final value = _zoomAnimation?.value;
          if (value != null) {
            _transformationController.value = value;
          }
        });
  }

  @override
  void dispose() {
    _zoomAnimationController.dispose();
    _transformationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _handlePageChanged(int index) {
    _zoomAnimationController.stop();
    _transformationController.value = Matrix4.identity();
    setState(() => _currentIndex = index);
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    _doubleTapLocalPosition = details.localPosition;
  }

  void _handleDoubleTap() {
    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    if (currentScale > 1.01) {
      _animateZoomTo(Matrix4.identity());
      return;
    }

    final position = _doubleTapLocalPosition;
    if (position == null) {
      return;
    }

    final target = Matrix4.identity()
      ..translateByDouble(
        -position.dx * (_doubleTapZoomScale - 1),
        -position.dy * (_doubleTapZoomScale - 1),
        0,
        1,
      )
      ..scaleByDouble(_doubleTapZoomScale, _doubleTapZoomScale, 1, 1);
    _animateZoomTo(target);
  }

  void _animateZoomTo(Matrix4 target) {
    _zoomAnimation =
        Matrix4Tween(
          begin: _transformationController.value,
          end: target,
        ).animate(
          CurvedAnimation(
            parent: _zoomAnimationController,
            curve: Curves.easeOut,
          ),
        );
    _zoomAnimationController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: AppColors.black,
      child: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: widget.imageUrls.length,
              onPageChanged: _handlePageChanged,
              itemBuilder: (context, index) {
                return Semantics(
                  label:
                      'Preview foto ${widget.merchantName} ${index + 1} dari ${widget.imageUrls.length}',
                  image: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onDoubleTapDown: _handleDoubleTapDown,
                    onDoubleTap: _handleDoubleTap,
                    child: InteractiveViewer(
                      transformationController: _transformationController,
                      minScale: 1,
                      maxScale: 4,
                      child: Center(
                        child: Image.network(
                          widget.imageUrls[index],
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.broken_image_outlined,
                              color: AppColors.white,
                              size: 54,
                            );
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) {
                              return child;
                            }

                            return const SizedBox(
                              width: 26,
                              height: 26,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: AppColors.white,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton.filled(
                tooltip: 'Tutup foto',
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.white.withValues(alpha: 0.14),
                  foregroundColor: AppColors.white,
                ),
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
            if (widget.imageUrls.length > 1)
              Positioned(
                left: 20,
                right: 20,
                bottom: 18,
                child: Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.black.withValues(alpha: 0.46),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.white.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      child: Text(
                        '${_currentIndex + 1}/${widget.imageUrls.length}',
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MerchantHeroImage extends StatelessWidget {
  const _MerchantHeroImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surfaceAlt,
      child: Image.network(
        imageUrl,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return const _MerchantHeroFallback(icon: Icons.broken_image_outlined);
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            return child;
          }

          return const _MerchantHeroFallback(
            icon: Icons.storefront_outlined,
            isLoading: true,
          );
        },
      ),
    );
  }
}

class _MerchantHeroFallback extends StatelessWidget {
  const _MerchantHeroFallback({required this.icon, this.isLoading = false});

  final IconData icon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceAlt,
      child: Center(
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: AppColors.primary,
                ),
              )
            : Icon(icon, size: 58, color: AppColors.primary),
      ),
    );
  }
}

class _MerchantInfo extends StatelessWidget {
  const _MerchantInfo({
    required this.merchant,
    required this.menuCount,
    this.displayDistance,
  });

  final MerchantModel merchant;
  final int menuCount;
  final String? displayDistance;

  @override
  Widget build(BuildContext context) {
    final distance = (displayDistance ?? merchant.distance).trim();
    final address = merchant.address.trim();
    final metadata = <String>[
      if (menuCount > 0) '$menuCount menu tersedia' else 'Menu',
      if (merchant.merchantType.trim().isNotEmpty)
        _merchantTypeLabel(merchant.merchantType),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          merchant.name,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: AppTextScaling.adaptive(context, normal: 18, large: 17),
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            height: 1.18,
          ),
        ),
        const SizedBox(height: 8),
        _MerchantMetadataLine(distance: distance, items: metadata),
        if (address.isNotEmpty) ...[
          const SizedBox(height: 8),
          _MerchantAddressLine(address: address),
        ],
      ],
    );
  }

  String _merchantTypeLabel(String value) {
    return switch (value.trim()) {
      'warung' => 'Warung',
      'convenience_store' => 'Minimarket',
      'other' => 'Toko',
      _ => 'Restoran',
    };
  }
}

class _MerchantAddressLine extends StatelessWidget {
  const _MerchantAddressLine({required this.address});

  final String address;

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      fontSize: AppTextScaling.adaptive(context, normal: 12, large: 11.5),
      color: AppColors.textSecondary,
      height: 1.35,
      fontWeight: FontWeight.w500,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 1.5),
          child: Icon(
            Icons.location_on_outlined,
            size: 15,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 5),
        Expanded(child: Text(address, style: textStyle)),
      ],
    );
  }
}

class _MerchantMetadataLine extends StatelessWidget {
  const _MerchantMetadataLine({required this.distance, required this.items});

  final String distance;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final hasDistance = distance.isNotEmpty && distance != '-';
    final visibleItems = items
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);

    if (!hasDistance && visibleItems.isEmpty) {
      return const SizedBox.shrink();
    }

    final textStyle = TextStyle(
      fontSize: AppTextScaling.adaptive(context, normal: 11.5, large: 11),
      color: AppColors.textSecondary,
      height: 1.25,
      fontWeight: FontWeight.w600,
    );

    final metadataLine = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasDistance)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.near_me_outlined,
                size: 14,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(distance, style: textStyle),
            ],
          ),
        for (final item in visibleItems) ...[
          if (hasDistance || item != visibleItems.first) ...[
            const SizedBox(width: 5),
            Text(
              '•',
              style: textStyle.copyWith(
                color: AppColors.textSecondary.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(width: 5),
          ],
          Text(item, style: textStyle),
        ],
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedWidth) {
          return metadataLine;
        }

        return SizedBox(
          width: constraints.maxWidth,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: metadataLine,
          ),
        );
      },
    );
  }
}

class _MenuSection extends StatelessWidget {
  const _MenuSection({
    required this.menus,
    required this.isLoading,
    required this.errorText,
  });

  final List<FoodModel> menus;
  final bool isLoading;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final hasPendingMenuPrices = menus.any((menu) => !menu.hasReferencePrice);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Menu Restoran',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        if (isLoading)
          const _MenuLoadingList()
        else if ((errorText ?? '').trim().isNotEmpty)
          _MenuInfoCard(icon: Icons.info_outline_rounded, message: errorText!)
        else if (menus.isEmpty)
          const _MenuInfoCard(
            icon: Icons.restaurant_menu_outlined,
            message: 'Menu resmi tempat ini belum tersedia.',
          )
        else ...[
          if (hasPendingMenuPrices) ...[
            const _MenuInfoCard(
              icon: Icons.receipt_long_outlined,
              message:
                  'Sebagian harga menu belum tersedia. Driver akan mengirim total barang sesuai nota.',
            ),
            const SizedBox(height: 10),
          ],
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: menus.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              return _MenuTile(menu: menus[index]);
            },
          ),
        ],
      ],
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.menu});

  final FoodModel menu;

  @override
  Widget build(BuildContext context) {
    final imageUrl = menu.imageUrl.trim();
    final hasImage = imageUrl.isNotEmpty;
    final hasReferencePrice = menu.hasReferencePrice;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: hasImage ? 10 : 14,
        vertical: hasImage ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: MenuItemRow(
        name: menu.name,
        priceLabel: menu.formattedPrice,
        imageUrl: imageUrl,
        thumbnailSize: 64,
        showThumbnailFallback: true,
        maxNameLines: hasImage ? 2 : 3,
        namePriceSpacing: 7,
        nameStyle: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14.5,
          fontWeight: FontWeight.w800,
          height: 1.25,
        ),
        priceStyle: TextStyle(
          color: hasReferencePrice
              ? AppColors.primary
              : AppColors.textSecondary,
          fontSize: 14,
          fontWeight: hasReferencePrice ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
    );
  }
}

class _MenuInfoCard extends StatelessWidget {
  const _MenuInfoCard({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13.5,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuLoadingList extends StatelessWidget {
  const _MenuLoadingList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < 3; index++) ...[
          Container(
            height: 86,
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
          ),
          if (index < 2) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _MerchantDetailLoadingState extends StatelessWidget {
  const _MerchantDetailLoadingState({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Detail Toko & Resto',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Kembali',
          icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary),
          onPressed: onBack,
        ),
      ),
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _MerchantDetailErrorState extends StatelessWidget {
  const _MerchantDetailErrorState({
    required this.message,
    required this.onBack,
  });

  final String message;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Detail Toko & Resto',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Kembali',
          icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary),
          onPressed: onBack,
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.info_outline,
                size: 38,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),
              TextButton(onPressed: onBack, child: const Text('Kembali')),
            ],
          ),
        ),
      ),
    );
  }
}
