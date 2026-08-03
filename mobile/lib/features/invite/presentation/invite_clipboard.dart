import 'package:flutter/services.dart';

abstract interface class InviteClipboard {
  Future<void> writeText(String text);
}

final class FlutterInviteClipboard implements InviteClipboard {
  const FlutterInviteClipboard();

  @override
  Future<void> writeText(String text) {
    return Clipboard.setData(ClipboardData(text: text));
  }
}
