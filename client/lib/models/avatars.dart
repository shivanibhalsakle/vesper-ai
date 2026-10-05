import 'package:flutter/material.dart';

/// Built-in avatars a user can pick instead of uploading a photo. The id is
/// what the backend stores, so keep ids stable; generated artwork can replace
/// the icons later without touching saved profiles.
class AvatarStyle {
  final IconData icon;
  final Color color;

  const AvatarStyle(this.icon, this.color);
}

const Map<String, AvatarStyle> kAvatars = {
  'sun': AvatarStyle(Icons.wb_sunny, Colors.orange),
  'moon': AvatarStyle(Icons.nightlight_round, Colors.indigo),
  'cloud': AvatarStyle(Icons.cloud, Colors.blueGrey),
  'wave': AvatarStyle(Icons.waves, Colors.teal),
  'mountain': AvatarStyle(Icons.landscape, Colors.green),
  'star': AvatarStyle(Icons.star, Colors.amber),
  'bird': AvatarStyle(Icons.flutter_dash, Colors.lightBlue),
  'tree': AvatarStyle(Icons.park, Colors.lightGreen),
};
