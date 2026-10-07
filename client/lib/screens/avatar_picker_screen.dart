import 'package:flutter/material.dart';

import '../models/avatars.dart';
import '../theme/app_motion.dart';
import '../theme/app_theme.dart';
import '../utils/haptics.dart';
import '../widgets/rise_in.dart';

/// Pick an illustrated avatar. The three groups are laid out one after
/// another under their headings; each avatar is a lifted circle.
///
/// Tapping one enlarges it and slides up a "Confirm avatar" button. Tapping
/// another moves the enlargement across (the button stays); tapping anywhere
/// else puts everything back and the button leaves. Confirming closes the
/// screen with the chosen avatar's id.
class AvatarPickerScreen extends StatefulWidget {
  const AvatarPickerScreen({super.key});

  @override
  State<AvatarPickerScreen> createState() => _AvatarPickerScreenState();
}

class _AvatarPickerScreenState extends State<AvatarPickerScreen> {
  String? _selected;

  void _select(String id) {
    if (_selected == id) return;
    AppHaptics.select();
    setState(() => _selected = id);
  }

  void _clear() {
    if (_selected != null) setState(() => _selected = null);
  }

  void _confirm() {
    final id = _selected;
    if (id == null) return;
    AppHaptics.tap();
    Navigator.of(context).pop(id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      appBar: AppBar(title: const Text('Choose your avatar')),
      body: Stack(
        children: [
          // Taps that land on no avatar (including on headings and the gaps)
          // end up here and clear the selection.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _clear,
              child: ListView(
                padding: EdgeInsets.fromLTRB(20, 4, 20, 110 + bottomInset),
                children: [
                  for (var i = 0; i < kAvatarGroups.length; i++)
                    RiseIn(
                      index: i,
                      child: _GroupSection(
                        group: kAvatarGroups[i],
                        selectedId: _selected,
                        onSelect: _select,
                      ),
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 20 + bottomInset,
            child: _ConfirmButton(visible: _selected != null, onPressed: _confirm),
          ),
        ],
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
    );
  }
}

class _GroupSection extends StatelessWidget {
  final AvatarGroup group;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  const _GroupSection({
    required this.group,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 14),
          child: Text(
            group.title,
            key: Key('avatar-group-${group.id}'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          // An enlarged avatar (and its shadow) spills past its cell, and
          // must not be cut off at the edge of the grid.
          clipBehavior: Clip.none,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            // Just taller than an avatar (80) so rows sit close together:
            // a 16px gap between circles, with room for the lift.
            mainAxisExtent: 88,
            mainAxisSpacing: 8,
            crossAxisSpacing: 16,
          ),
          children: [
            for (final avatar in group.avatars)
              _AvatarTile(
                avatar: avatar,
                selected: avatar.id == selectedId,
                onTap: () => onSelect(avatar.id),
              ),
          ],
        ),
      ],
    );
  }
}

/// One lifted circle: it floats on a soft shadow, and when selected it grows,
/// rises further and gains a ring.
class _AvatarTile extends StatelessWidget {
  static const _scale = 1.2;

  final AvatarOption avatar;
  final bool selected;
  final VoidCallback onTap;

  const _AvatarTile({required this.avatar, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final reduced = AppMotion.reduced(context);
    final duration = reduced ? Duration.zero : const Duration(milliseconds: 300);

    return Center(
      child: Semantics(
        button: true,
        selected: selected,
        label: avatar.label,
        excludeSemantics: true,
        child: GestureDetector(
          key: Key('avatar-${avatar.id}'),
          onTap: onTap,
          child: AnimatedScale(
            scale: selected ? _scale : 1.0,
            duration: duration,
            curve: Curves.easeOutBack,
            child: AnimatedContainer(
              duration: duration,
              curve: Curves.easeOut,
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // The ring is always there (transparent) so the circle never
                // changes size when it appears.
                border: Border.all(
                  color: selected ? AppColors.brown : Colors.transparent,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.brownDark.withValues(alpha: selected ? 0.35 : 0.2),
                    blurRadius: selected ? 20 : 8,
                    offset: Offset(0, selected ? 10 : 3),
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  avatar.asset,
                  fit: BoxFit.cover,
                  cacheWidth: (80 * _scale * MediaQuery.devicePixelRatioOf(context)).round(),
                  gaplessPlayback: true,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Confirm avatar", sliding up from below when there is something to
/// confirm and back down when there isn't.
class _ConfirmButton extends StatelessWidget {
  final bool visible;
  final VoidCallback onPressed;

  const _ConfirmButton({required this.visible, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final duration = AppMotion.reduced(context) ? Duration.zero : const Duration(milliseconds: 300);

    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        offset: visible ? Offset.zero : const Offset(0, 1.6),
        duration: duration,
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: duration,
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const Key('confirm-avatar'),
              onPressed: onPressed,
              child: const Text('Confirm avatar'),
            ),
          ),
        ),
      ),
    );
  }
}
