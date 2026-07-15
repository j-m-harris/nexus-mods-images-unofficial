import 'package:flutter/material.dart';

import '../services/settings_service.dart';
import '../theme.dart';

/// One-time 18+ confirmation shown before adult content is first exposed:
/// picking the Show mode in settings, or tapping to reveal a veiled image.
///
/// Returns true when the content may be shown. The first acceptance is
/// persisted via [SettingsService.confirmAdult], so the dialog never appears
/// again; declining leaves the flag unset and the caller shows nothing.
Future<bool> ensureAdultConfirmed(BuildContext context) async {
  if (SettingsService.instance.adultConfirmed) return true;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: NexusColors.surface,
      title: const Text(
        'Adult content',
        style: TextStyle(color: NexusColors.textPrimary),
      ),
      content: const Text(
        'Nexus Mods marks some images as adult. Confirm you are 18 or older '
        'to view them.',
        style: TextStyle(color: NexusColors.textMuted),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text(
            'Cancel',
            style: TextStyle(color: NexusColors.textMuted),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text(
            'I am 18 or older',
            style: TextStyle(color: NexusColors.primary),
          ),
        ),
      ],
    ),
  );
  if (confirmed != true) return false;
  await SettingsService.instance.confirmAdult();
  return true;
}
