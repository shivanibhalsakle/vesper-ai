import 'package:flutter/material.dart';

import '../models/avatars.dart';

/// The user's picture: a photo if there is one, else their chosen avatar,
/// else the first letter of their name.
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

    final avatar = avatarId == null ? null : kAvatars[avatarId];
    if (avatar != null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: avatar.color.withValues(alpha: 0.2),
        child: Icon(avatar.icon, size: radius, color: avatar.color),
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
