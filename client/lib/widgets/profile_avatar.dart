import 'package:flutter/material.dart';

import '../models/avatars.dart';

/// The user's picture: a photo if there is one, else their chosen illustrated
/// avatar, else the first letter of their name.
class ProfileAvatar extends StatelessWidget {
  final double radius;
  final ImageProvider? image;
  final String? avatarId;
  final String? name;

  const ProfileAvatar({
    super.key,
    this.radius = 40,
    this.image,
    this.avatarId,
    this.name,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (image != null) {
      return CircleAvatar(radius: radius, backgroundImage: image);
    }

    final avatar = avatarById(avatarId);
    if (avatar != null) {
      return SizedBox.square(
        dimension: radius * 2,
        // The artwork is already a circle on a transparent square.
        child: Image.asset(
          avatar.asset,
          fit: BoxFit.cover,
          semanticLabel: avatar.label,
          // Decode near the size shown (and sharp on dense screens) rather
          // than at full resolution.
          cacheWidth: (radius * 2 * MediaQuery.devicePixelRatioOf(context)).round(),
          gaplessPlayback: true,
        ),
      );
    }

    final trimmed = name?.trim() ?? '';
    return CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primaryContainer,
      child: trimmed.isEmpty
          ? Icon(Icons.person, size: radius, color: scheme.onPrimaryContainer)
          : Text(
              trimmed[0].toUpperCase(),
              style: TextStyle(fontSize: radius, color: scheme.onPrimaryContainer),
            ),
    );
  }
}
