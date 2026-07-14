import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme.dart';

/// Frosted veil laid over an adult-flagged image while the adult-content
/// setting is off: blurs whatever is underneath and invites a tap to reveal.
/// Purely visual — the owning widget handles the reveal tap itself.
///
/// Expects to be a child of the image's [Stack].
class AdultContentVeil extends StatelessWidget {
  /// Icon-only layout for small grid tiles, where the caption would not fit.
  final bool compact;

  const AdultContentVeil({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: ColoredBox(
            color: Colors.black.withValues(alpha: 0.35),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.visibility_off_outlined,
                    color: NexusColors.textPrimary,
                    size: compact ? 20 : 28,
                  ),
                  if (!compact) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Adult content',
                      style: TextStyle(
                        color: NexusColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Tap to view',
                      style: TextStyle(
                        color: NexusColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
