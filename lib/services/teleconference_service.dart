import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class TeleconferenceService {
  static const String invitePrefix = '[TELECONFERENCE_INVITE:';

  static String? roomFromInvite(String? content) {
    final value = content?.trim() ?? '';
    if (!value.startsWith(invitePrefix) || !value.endsWith(']')) return null;
    final room = value.substring(invitePrefix.length, value.length - 1);
    return room.isEmpty ? null : room;
  }

  static Future<void> join({
    required BuildContext context,
    required String? meetingRoom,
  }) async {
    final room = meetingRoom?.trim() ?? '';
    if (room.isEmpty) {
      _showError(context, 'The video consultation room is not ready yet.');
      return;
    }

    final safeRoom = room.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
    final uri = Uri.https('meet.jit.si', '/$safeRoom');

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        _showError(context, 'Unable to open the video consultation.');
      }
    } catch (_) {
      if (context.mounted) {
        _showError(context, 'Unable to open the video consultation.');
      }
    }
  }

  static void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
