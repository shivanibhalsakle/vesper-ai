import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vesper/theme/app_theme.dart';

double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

/// WCAG contrast ratio between two colours (1 to 21).
double _contrast(Color a, Color b) {
  final l1 = _luminance(a);
  final l2 = _luminance(b);
  return (math.max(l1, l2) + 0.05) / (math.min(l1, l2) + 0.05);
}

void main() {
  final theme = buildAppTheme();

  test('pages are white, buttons brown, cards beige', () {
    expect(theme.scaffoldBackgroundColor, AppColors.white);
    expect(theme.colorScheme.primary, AppColors.brown);
    expect(theme.cardTheme.color, AppColors.beige);
    expect(theme.cardTheme.shape, isA<RoundedRectangleBorder>());
    expect(
      (theme.cardTheme.shape as RoundedRectangleBorder).side.color,
      AppColors.beigeBorder,
    );
    expect(
      theme.filledButtonTheme.style!.backgroundColor!.resolve({}),
      AppColors.brown,
    );
    expect(theme.inputDecorationTheme.fillColor, AppColors.beige);
  });

  test('headlines use Fraunces and body text uses DM Sans', () {
    expect(theme.textTheme.headlineSmall!.fontFamily, 'Fraunces');
    expect(theme.textTheme.titleLarge!.fontFamily, 'Fraunces');
    // The big, short moments (scores, the wordmark) use the brush script.
    expect(theme.textTheme.displaySmall!.fontFamily, 'KaushanScript');
    expect(theme.textTheme.displayMedium!.fontFamily, 'KaushanScript');
    expect(theme.textTheme.titleMedium!.fontFamily, 'DMSans');
    expect(theme.textTheme.bodyMedium!.fontFamily, 'DMSans');
    expect(theme.textTheme.labelLarge!.fontFamily, 'DMSans');
    expect(theme.appBarTheme.titleTextStyle!.fontFamily, 'Fraunces');
  });

  test('every font file the pubspec declares is bundled, with its licence', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final assets = RegExp(r'asset: (assets/fonts/[\w\-]+\.ttf)')
        .allMatches(pubspec)
        .map((m) => m.group(1)!)
        .toList();

    expect(assets, hasLength(8));
    for (final asset in assets) {
      expect(File(asset).existsSync(), isTrue, reason: '$asset is missing');
    }
    expect(File('assets/fonts/OFL-DMSans.txt').existsSync(), isTrue);
    expect(File('assets/fonts/OFL-Fraunces.txt').existsSync(), isTrue);
    expect(File('assets/fonts/OFL-KaushanScript.txt').existsSync(), isTrue);
  });

  group('text stays readable (WCAG AA, 4.5:1)', () {
    const aa = 4.5;

    test('body text on white and on cards', () {
      expect(_contrast(AppColors.text, AppColors.white), greaterThan(aa));
      expect(_contrast(AppColors.text, AppColors.beige), greaterThan(aa));
      expect(_contrast(AppColors.text, AppColors.blush), greaterThan(aa));
    });

    test('secondary text on white and on cards', () {
      expect(_contrast(AppColors.textSecondary, AppColors.white), greaterThan(aa));
      expect(_contrast(AppColors.textSecondary, AppColors.beige), greaterThan(aa));
    });

    test('white text on brown buttons', () {
      expect(_contrast(AppColors.white, AppColors.brown), greaterThan(aa));
    });

    test('brown links and outlined buttons on white and beige', () {
      expect(_contrast(AppColors.brown, AppColors.white), greaterThan(aa));
      expect(_contrast(AppColors.brown, AppColors.beige), greaterThan(aa));
    });

    test('selected controls and tonal buttons', () {
      expect(_contrast(AppColors.brownDark, AppColors.blush), greaterThan(aa));
    });

    test('error text on white and on its container', () {
      expect(_contrast(AppColors.error, AppColors.white), greaterThan(aa));
      expect(_contrast(AppColors.error, AppColors.errorContainer), greaterThan(aa));
    });
  });

  testWidgets('the theme applies to real widgets', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: theme,
      home: Scaffold(
        appBar: AppBar(title: const Text('Title')),
        body: Column(
          children: [
            FilledButton(onPressed: () {}, child: const Text('Go')),
            const Card(child: Text('Card')),
          ],
        ),
      ),
    ));

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor ?? theme.scaffoldBackgroundColor, AppColors.white);

    final button = tester.widget<Material>(
      find.descendant(of: find.byType(FilledButton), matching: find.byType(Material)),
    );
    expect(button.color, AppColors.brown);

    final card = tester.widget<Material>(
      find.descendant(of: find.byType(Card), matching: find.byType(Material)).first,
    );
    expect(card.color, AppColors.beige);
  });
}
