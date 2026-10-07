import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'haptics.dart';

/// Opens a URL outside the app. Replaceable so tests never leave the app.
typedef UrlOpener = Future<bool> Function(Uri uri);

Future<bool> _launchExternally(Uri uri) => launchUrl(uri, mode: LaunchMode.externalApplication);

class MapsLauncher {
  MapsLauncher._();

  static UrlOpener opener = _launchExternally;

  /// Google's universal map link: it opens the Google Maps app when that is
  /// installed and falls back to the browser otherwise. Coordinates (not the
  /// name) are used so the pin lands exactly on the spot.
  static Uri uriFor(double lat, double lon) => Uri.https('www.google.com', '/maps/search/', {
        'api': '1',
        'query': '$lat,$lon',
      });
}

/// Asks "Open in Google Maps?" and, on yes, opens [name]'s coordinates there.
Future<void> confirmAndOpenInMaps(
  BuildContext context, {
  required String name,
  required double lat,
  required double lon,
}) async {
  AppHaptics.tap();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      key: const Key('open-in-maps-dialog'),
      title: const Text('Open in Google Maps?'),
      content: Text(name),
      actions: [
        TextButton(
          key: const Key('open-in-maps-cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('open-in-maps-confirm'),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Open Google Maps'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  bool opened;
  try {
    opened = await MapsLauncher.opener(MapsLauncher.uriFor(lat, lon));
  } catch (_) {
    opened = false;
  }
  if (!opened) {
    messenger.showSnackBar(
      const SnackBar(content: Text("Couldn't open Google Maps on this device.")),
    );
  }
}
