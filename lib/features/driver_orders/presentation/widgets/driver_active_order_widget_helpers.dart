import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../config/app_colors.dart';
import '../../../navigation/presentation/widgets/bang_floating_bottom_nav_bar.dart';
import '../../../../utils/currency_input_parser.dart';

class DriverActiveOrderSnackBarScope extends InheritedWidget {
  const DriverActiveOrderSnackBarScope({
    super.key,
    required this.stickyActionBarKey,
    required super.child,
  });

  final GlobalKey stickyActionBarKey;

  static DriverActiveOrderSnackBarScope? maybeOf(BuildContext context) {
    final widget = context
        .getElementForInheritedWidgetOfExactType<
          DriverActiveOrderSnackBarScope
        >()
        ?.widget;

    return widget is DriverActiveOrderSnackBarScope ? widget : null;
  }

  @override
  bool updateShouldNotify(DriverActiveOrderSnackBarScope oldWidget) {
    return stickyActionBarKey != oldWidget.stickyActionBarKey;
  }
}

void showDriverActiveOrderSnackBar(
  BuildContext context, {
  required String message,
  bool isError = false,
  GlobalKey? stickyActionBarKey,
}) {
  final bottomInset = _driverActiveOrderSnackBarBottomInset(
    context,
    stickyActionBarKey: stickyActionBarKey,
  );

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(16, 0, 16, bottomInset),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
}

double _driverActiveOrderSnackBarBottomInset(
  BuildContext context, {
  GlobalKey? stickyActionBarKey,
}) {
  final resolvedKey =
      stickyActionBarKey ??
      DriverActiveOrderSnackBarScope.maybeOf(context)?.stickyActionBarKey;
  final renderObject = resolvedKey?.currentContext?.findRenderObject();
  final actionBarHeight = renderObject is RenderBox && renderObject.hasSize
      ? renderObject.size.height
      : 0.0;

  if (actionBarHeight > 1) {
    return actionBarHeight + BangFloatingBottomNavBar.snackBarGap;
  }

  return BangFloatingBottomNavBar.snackBarBottomInset(context);
}

InputDecoration driverDialogInputDecoration({
  String? labelText,
  String? hintText,
  String? prefixText,
  String? errorText,
}) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: AppColors.border),
  );

  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    prefixText: prefixText,
    errorText: errorText,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    labelStyle: const TextStyle(
      color: AppColors.textSecondary,
      fontSize: 13,
      fontWeight: FontWeight.w600,
    ),
    hintStyle: const TextStyle(
      color: AppColors.textSecondary,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    ),
    border: border,
    enabledBorder: border,
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
    ),
  );
}

double parseDriverCurrencyInput(String raw) {
  return parseCurrencyInput(raw);
}

Future<XFile?> pickDriverOrderImage(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    useRootNavigator: true,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
    ),
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Ambil dari kamera'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pilih dari galeri'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      );
    },
  );

  if (source == null) {
    return null;
  }

  return ImagePicker().pickImage(
    source: source,
    imageQuality: 76,
    maxWidth: 1600,
  );
}
