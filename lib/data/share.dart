import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _channel = MethodChannel('revup/share');

/// Opens the phone's share sheet with [text]. Where there is none (web,
/// tests) it copies the text and says so.
Future<void> shareText(BuildContext context, String text) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    if (await _channel.invokeMethod<bool>('shareText', {'text': text}) ==
        true) {
      return;
    }
  } on MissingPluginException {
    // No native side on this platform.
  } on PlatformException {
    // Share sheet failed to open.
  }
  await Clipboard.setData(ClipboardData(text: text));
  messenger.showSnackBar(
    const SnackBar(content: Text('Copied. Paste it into WhatsApp or SMS.')),
  );
}
