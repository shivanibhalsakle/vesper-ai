import 'dart:io';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vesper/models/avatars.dart';
import 'package:vesper/screens/avatar_picker_screen.dart';
import 'package:vesper/theme/app_theme.dart';
import 'package:vesper/widgets/profile_avatar.dart';

// What the backend accepts for an avatar id (see app/schemas/user_profile.py).
final _backendIdPattern = RegExp(r'^[a-z][a-z0-9_]{0,31}$');

Widget _app(Widget home, {bool reduceMotion = false}) => MaterialApp(
      theme: buildAppTheme(),
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: app!,
      ),
      home: home,
    );

Future<void> _pumpPicker(WidgetTester tester, {bool reduce = false}) async {
  tester.view.physicalSize = const Size(800, 3600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(const AvatarPickerScreen(), reduceMotion: reduce));
  await tester.pumpAndSettle();
}

Finder _tile(String id) => find.byKey(Key('avatar-$id'));

double _scaleOf(WidgetTester tester, String id) => tester
    .widget<AnimatedScale>(find.descendant(of: _tile(id), matching: find.byType(AnimatedScale)))
    .scale;

double _shadowBlur(WidgetTester tester, String id) {
  final container = tester.widget<AnimatedContainer>(
    find.descendant(of: _tile(id), matching: find.byType(AnimatedContainer)),
  );
  return ((container.decoration! as BoxDecoration).boxShadow!.first).blurRadius;
}

double _confirmOpacity(WidgetTester tester) => tester
    .widget<AnimatedOpacity>(
      find.ancestor(of: find.byKey(const Key('confirm-avatar')), matching: find.byType(AnimatedOpacity)),
    )
    .opacity;

bool _confirmTappable(WidgetTester tester) {
  final ignore = tester.widget<IgnorePointer>(
    find.ancestor(of: find.byKey(const Key('confirm-avatar')), matching: find.byType(IgnorePointer)).first,
  );
  return !ignore.ignoring;
}

void main() {
  group('the avatar catalogue', () {
    final all = [for (final g in kAvatarGroups) ...g.avatars];

    test('three groups, in the order they are shown', () {
      expect(kAvatarGroups.map((g) => g.id), ['wanderlust', 'wilderness', 'moods']);
      expect(kAvatarGroups.map((g) => g.title), ['Wanderlust', 'Wilderness', 'Moods']);
      expect(kAvatarGroups.map((g) => g.avatars.length), [8, 10, 6]);
    });

    test('every id is unique and acceptable to the backend', () {
      expect(all.map((a) => a.id).toSet(), hasLength(all.length));
      for (final avatar in all) {
        expect(_backendIdPattern.hasMatch(avatar.id), isTrue, reason: avatar.id);
      }
    });

    test('every avatar has a label and its artwork file exists', () {
      for (final group in kAvatarGroups) {
        for (final avatar in group.avatars) {
          expect(avatar.label, isNotEmpty, reason: avatar.id);
          expect(avatar.asset, 'assets/avatars/${group.id}/${avatar.id}.webp');
          expect(File(avatar.asset).existsSync(), isTrue, reason: '${avatar.asset} is missing');
        }
      }
    });

    test('every artwork file is a circle on a transparent square', () {
      // WebP files start with RIFF....WEBP; the alpha-capable variants carry
      // a VP8X or ALPH chunk, so a quick header check catches a flattened export.
      for (final avatar in all) {
        final bytes = File(avatar.asset).readAsBytesSync();
        expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF', reason: avatar.id);
        expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WEBP', reason: avatar.id);
        expect(String.fromCharCodes(bytes), contains('ALPH'), reason: '${avatar.id} has no alpha');
      }
    });

    test('lookup by id', () {
      expect(avatarById('wilderness_wolf')!.label, 'Howling wolf');
      expect(avatarById('moods_mint')!.asset, endsWith('moods_mint.webp'));
      expect(avatarById('sun'), isNull); // the old icon avatars are gone
      expect(avatarById(null), isNull);
    });
  });

  group('ProfileAvatar', () {
    testWidgets('shows the illustrated avatar for a known id', (tester) async {
      await tester.pumpWidget(_app(const Scaffold(
        body: Center(child: ProfileAvatar(avatarId: 'wilderness_wolf', name: 'Shivani')),
      )));

      final image = tester.widget<Image>(find.byType(Image));
      expect(
        ((image.image as ResizeImage).imageProvider as AssetImage).assetName,
        'assets/avatars/wilderness/wilderness_wolf.webp',
      );
      expect(find.text('S'), findsNothing);
    });

    testWidgets('falls back to the initial for an id this version does not know', (tester) async {
      await tester.pumpWidget(_app(const Scaffold(
        body: Center(child: ProfileAvatar(avatarId: 'from_the_future', name: 'Shivani')),
      )));

      expect(find.byType(Image), findsNothing);
      expect(find.text('S'), findsOneWidget);
    });
  });

  group('AvatarPickerScreen', () {
    testWidgets('shows every group under its heading, in order, with every avatar',
        (tester) async {
      await _pumpPicker(tester);

      final wanderlust = tester.getTopLeft(find.byKey(const Key('avatar-group-wanderlust'))).dy;
      final wilderness = tester.getTopLeft(find.byKey(const Key('avatar-group-wilderness'))).dy;
      final moods = tester.getTopLeft(find.byKey(const Key('avatar-group-moods'))).dy;
      expect(wanderlust, lessThan(wilderness));
      expect(wilderness, lessThan(moods));

      for (final heading in ['Wanderlust', 'Wilderness', 'Moods']) {
        expect(find.text(heading), findsOneWidget);
      }
      for (final group in kAvatarGroups) {
        for (final avatar in group.avatars) {
          expect(_tile(avatar.id), findsOneWidget, reason: avatar.id);
        }
      }

      // Each avatar sits under its own group's heading.
      final firstWilderness = tester.getTopLeft(_tile('wilderness_snake')).dy;
      expect(firstWilderness, greaterThan(wilderness));
      expect(firstWilderness, lessThan(moods));
    });

    testWidgets('rows within a group sit close together without touching', (tester) async {
      await _pumpPicker(tester);

      // wanderlust_01 and _04 are the first avatars of the first two rows.
      final topRow = tester.getRect(_tile('wanderlust_01'));
      final nextRow = tester.getRect(_tile('wanderlust_04'));
      final gap = nextRow.top - topRow.bottom;

      expect(gap, inInclusiveRange(10, 24)); // snug, but room for the lift
    });

    testWidgets('avatars are lifted circles that start at normal size, with no button',
        (tester) async {
      await _pumpPicker(tester);

      expect(_scaleOf(tester, 'wanderlust_01'), 1.0);
      expect(_shadowBlur(tester, 'wanderlust_01'), greaterThan(0));
      expect(_confirmOpacity(tester), 0);
      expect(_confirmTappable(tester), isFalse);
    });

    testWidgets('tapping an avatar enlarges and lifts it and brings up Confirm avatar',
        (tester) async {
      await _pumpPicker(tester);
      final liftedBefore = _shadowBlur(tester, 'wilderness_wolf');

      await tester.tap(_tile('wilderness_wolf'));
      await tester.pump(const Duration(milliseconds: 120)); // mid-animation
      expect(_scaleOf(tester, 'wilderness_wolf'), 1.2);
      await tester.pumpAndSettle();

      expect(_shadowBlur(tester, 'wilderness_wolf'), greaterThan(liftedBefore));
      expect(_confirmOpacity(tester), 1);
      expect(_confirmTappable(tester), isTrue);
      expect(find.text('Confirm avatar'), findsOneWidget);
    });

    testWidgets('tapping another moves the enlargement and keeps the button', (tester) async {
      await _pumpPicker(tester);

      await tester.tap(_tile('wilderness_wolf'));
      await tester.pumpAndSettle();
      await tester.tap(_tile('moods_mint'));
      await tester.pumpAndSettle();

      expect(_scaleOf(tester, 'wilderness_wolf'), 1.0);
      expect(_scaleOf(tester, 'moods_mint'), 1.2);
      expect(_confirmOpacity(tester), 1);
      expect(_confirmTappable(tester), isTrue);
    });

    testWidgets('tapping the enlarged avatar again leaves it selected', (tester) async {
      await _pumpPicker(tester);

      await tester.tap(_tile('wanderlust_03'));
      await tester.pumpAndSettle();
      await tester.tap(_tile('wanderlust_03'));
      await tester.pumpAndSettle();

      expect(_scaleOf(tester, 'wanderlust_03'), 1.2);
      expect(_confirmTappable(tester), isTrue);
    });

    testWidgets('tapping away puts the avatar back and the button leaves', (tester) async {
      await _pumpPicker(tester);
      await tester.tap(_tile('wilderness_wolf'));
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(4, 500)); // empty margin beside the grid
      await tester.pumpAndSettle();

      expect(_scaleOf(tester, 'wilderness_wolf'), 1.0);
      expect(_confirmOpacity(tester), 0);
      expect(_confirmTappable(tester), isFalse);
    });

    testWidgets('tapping a heading also counts as tapping away', (tester) async {
      await _pumpPicker(tester);
      await tester.tap(_tile('moods_ocean'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Wilderness'));
      await tester.pumpAndSettle();

      expect(_scaleOf(tester, 'moods_ocean'), 1.0);
      expect(_confirmTappable(tester), isFalse);
    });

    testWidgets('confirming closes the screen with the chosen id', (tester) async {
      String? chosen;
      var closed = false;
      tester.view.physicalSize = const Size(800, 3600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async {
                chosen = await Navigator.of(context).push<String>(
                  MaterialPageRoute(builder: (_) => const AvatarPickerScreen()),
                );
                closed = true;
              },
              child: const Text('Open'),
            ),
          ),
        ),
      )));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(_tile('wanderlust_06'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-avatar')));
      await tester.pumpAndSettle();

      expect(closed, isTrue);
      expect(chosen, 'wanderlust_06');
    });

    testWidgets('going back without confirming returns nothing', (tester) async {
      String? chosen = 'unset';
      tester.view.physicalSize = const Size(800, 3600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async {
                chosen = await Navigator.of(context).push<String>(
                  MaterialPageRoute(builder: (_) => const AvatarPickerScreen()),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      )));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(_tile('wanderlust_06')); // picked, but never confirmed
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(chosen, isNull);
    });

    testWidgets('screen readers hear each avatar, its selected state, and it is a button',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpPicker(tester);
      expect(find.bySemanticsLabel('Howling wolf'), findsOneWidget);

      var node = tester.getSemantics(_tile('wilderness_wolf'));
      expect(node.flagsCollection.isSelected, Tristate.isFalse);

      await tester.tap(_tile('wilderness_wolf'));
      await tester.pumpAndSettle();
      node = tester.getSemantics(_tile('wilderness_wolf'));
      expect(node.flagsCollection.isSelected, Tristate.isTrue);
      expect(node.flagsCollection.isButton, isTrue);
      handle.dispose();
    });

    testWidgets('reduced motion: the enlargement and button switch instantly', (tester) async {
      await _pumpPicker(tester, reduce: true);

      await tester.tap(_tile('moods_peach'));
      await tester.pump(); // a single frame, no animation to wait for
      await tester.pump(const Duration(milliseconds: 20));

      expect(_scaleOf(tester, 'moods_peach'), 1.2);
      expect(_confirmOpacity(tester), 1);
      await tester.pumpAndSettle();
    });
  });
}
