import 'package:flutter/material.dart';

Future<void> showBangNetworkImagePreview(
  BuildContext context, {
  required String imageUrl,
}) {
  final url = imageUrl.trim();
  if (url.isEmpty) {
    return Future<void>.value();
  }

  return showDialog<void>(
    context: context,
    builder: (context) {
      final size = MediaQuery.sizeOf(context);

      return Dialog(
        insetPadding: const EdgeInsets.all(18),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: size.width,
            maxHeight: size.height * 0.82,
          ),
          child: InteractiveViewer(
            minScale: 0.8,
            maxScale: 5,
            child: Image.network(
              url,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) {
                  return child;
                }

                return const SizedBox(
                  width: 240,
                  height: 320,
                  child: Center(child: CircularProgressIndicator()),
                );
              },
              errorBuilder: (_, _, _) => const SizedBox(
                width: 240,
                height: 320,
                child: Center(child: Icon(Icons.broken_image_outlined)),
              ),
            ),
          ),
        ),
      );
    },
  );
}
