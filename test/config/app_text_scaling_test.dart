import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bangdeliv/config/app_text_scaling.dart';

void main() {
  testWidgets('clamps very large text scale to BangDeliv maximum', (
    tester,
  ) async {
    late double scaledFontSize;

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) {
              return AppTextScaling.clamp(
                context: context,
                child: Builder(
                  builder: (context) {
                    scaledFontSize = MediaQuery.textScalerOf(context).scale(10);

                    return const SizedBox.shrink();
                  },
                ),
              );
            },
          ),
        ),
      ),
    );

    expect(scaledFontSize, 10 * AppTextScaling.maxScaleFactor);
  });

  testWidgets('keeps normal text scale unchanged', (tester) async {
    late double scaledFontSize;

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) {
              return AppTextScaling.clamp(
                context: context,
                child: Builder(
                  builder: (context) {
                    scaledFontSize = MediaQuery.textScalerOf(context).scale(10);

                    return const SizedBox.shrink();
                  },
                ),
              );
            },
          ),
        ),
      ),
    );

    expect(scaledFontSize, 10);
  });

  testWidgets('keeps smaller user text scale unchanged', (tester) async {
    late double scaledFontSize;

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(0.85)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) {
              return AppTextScaling.clamp(
                context: context,
                child: Builder(
                  builder: (context) {
                    scaledFontSize = MediaQuery.textScalerOf(context).scale(10);

                    return const SizedBox.shrink();
                  },
                ),
              );
            },
          ),
        ),
      ),
    );

    expect(scaledFontSize, 8.5);
  });

  testWidgets('clamps compact components with a tighter maximum', (
    tester,
  ) async {
    late double scaledFontSize;

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) {
              return AppTextScaling.clampForCompactComponent(
                context: context,
                child: Builder(
                  builder: (context) {
                    scaledFontSize = MediaQuery.textScalerOf(context).scale(10);

                    return const SizedBox.shrink();
                  },
                ),
              );
            },
          ),
        ),
      ),
    );

    expect(scaledFontSize, 10 * AppTextScaling.compactComponentMaxScaleFactor);
  });

  testWidgets('interpolates adaptive values across text scale range', (
    tester,
  ) async {
    late double adaptiveValue;

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) {
              adaptiveValue = AppTextScaling.adaptive(
                context,
                normal: 20,
                large: 16,
              );

              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(adaptiveValue, 16);
  });
}
