import 'package:flutter/material.dart';

import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

import 'main.dart'; // To get bgDarkBlue, cardDarkBlue, gameYellow, fontWhite, HapticType

class SettingsDialog extends StatefulWidget {
  final bool soundEnabled;
  final bool vibrationEnabled;
  final ValueChanged<bool> onSoundChanged;
  final ValueChanged<bool> onVibrationChanged;
  final VoidCallback onMoreSettings;

  const SettingsDialog({
    super.key,
    required this.soundEnabled,
    required this.vibrationEnabled,
    required this.onSoundChanged,
    required this.onVibrationChanged,
    required this.onMoreSettings,
  });

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late bool soundEnabled;
  late bool vibrationEnabled;

  @override
  void initState() {
    super.initState();
    soundEnabled = widget.soundEnabled;
    vibrationEnabled = widget.vibrationEnabled;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: cardDarkBlue,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('SETTINGS',
                style: TextStyle(
                    color: fontWhite,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2)),
            const SizedBox(height: 24),
            SettingsRow(
              icon: Icons.volume_up_rounded,
              label: 'Sound',
              value: soundEnabled,
              onChanged: (v) {
                setState(() => soundEnabled = v);
                widget.onSoundChanged(v);
              },
            ),
            const SizedBox(height: 16),
            SettingsRow(
              icon: Icons.vibration_rounded,
              label: 'Vibration',
              value: vibrationEnabled,
              onChanged: (v) {
                setState(() => vibrationEnabled = v);
                widget.onVibrationChanged(v);
              },
            ),
            const SizedBox(height: 8),
            Divider(color: fontWhite.withValues(alpha: 0.1)),
            TextButton(
              onPressed: widget.onMoreSettings,
              child: Text(
                'More Settings',
                style: TextStyle(
                  color: fontWhite.withValues(alpha: 0.7),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MoreSettingsDialog extends StatefulWidget {
  final bool notificationsEnabled;
  final ValueChanged<bool> onNotificationsChanged;
  final VoidCallback onHapticLight;

  const MoreSettingsDialog({
    super.key,
    required this.notificationsEnabled,
    required this.onNotificationsChanged,
    required this.onHapticLight,
  });

  @override
  State<MoreSettingsDialog> createState() => _MoreSettingsDialogState();
}

class _MoreSettingsDialogState extends State<MoreSettingsDialog> {
  late bool notificationsEnabled;

  @override
  void initState() {
    super.initState();
    notificationsEnabled = widget.notificationsEnabled;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: cardDarkBlue,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('MORE SETTINGS',
                style: TextStyle(
                    color: fontWhite,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2)),
            const SizedBox(height: 24),
            SettingsRow(
              icon: Icons.notifications_rounded,
              label: 'Daily Reminders',
              value: notificationsEnabled,
              onChanged: (v) {
                setState(() => notificationsEnabled = v);
                widget.onNotificationsChanged(v);
              },
            ),
            const SizedBox(height: 16),
            Divider(color: fontWhite.withValues(alpha: 0.1)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bgDarkBlue.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text('BigBlueBlocks',
                          style: TextStyle(
                              color: fontWhite,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                      Text('Version 1.2.0',
                          style: TextStyle(
                              color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            LinkRow(
              icon: Icons.mail_rounded,
              label: 'Contact Us',
              onHapticLight: widget.onHapticLight,
              onTap: () {
                final Uri emailLaunchUri = Uri(
                  scheme: 'mailto',
                  path: 'support@bigblueblocks.app',
                  queryParameters: {'subject': 'Support Request - Big Blue Blocks'},
                );
                launchUrl(emailLaunchUri);
              },
            ),
            LinkRow(
              icon: Icons.share_rounded,
              label: 'Share with friends',
              onHapticLight: widget.onHapticLight,
              onTap: () {
                final size = MediaQuery.of(context).size;
                Share.share(
                  'Check out Big Blue Blocks! The ultimate puzzle experience for your mind. https://bigblueblocks.app',
                  sharePositionOrigin: Rect.fromLTWH(0, size.height / 2, size.width, size.height / 2),
                );
              },
            ),
            const SizedBox(height: 12),
            Divider(color: fontWhite.withValues(alpha: 0.1)),
            const SizedBox(height: 12),
            LinkRow(
              icon: Icons.description_rounded,
              label: 'Terms of Service',
              onHapticLight: widget.onHapticLight,
              onTap: () => launchUrl(Uri.parse('https://bigblueblocks.app/terms.html')),
            ),
            LinkRow(
              icon: Icons.privacy_tip_rounded,
              label: 'Privacy Policy',
              onHapticLight: widget.onHapticLight,
              onTap: () => launchUrl(Uri.parse('https://bigblueblocks.app/privacy.html')),
            ),
            LinkRow(
              icon: Icons.info_rounded,
              label: 'About Us',
              onHapticLight: widget.onHapticLight,
              onTap: () {
                Navigator.pop(context);
                showAboutDialog(
                  context: context,
                  applicationName: 'BigBlueBlocks',
                  applicationVersion: '1.2.0',
                  applicationLegalese: '© 2026 BigBlueBlocks',
                );
              },
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close',
                  style: TextStyle(color: gameYellow, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

class LinkRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final VoidCallback onHapticLight;

  const LinkRow({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    required this.onHapticLight,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: GestureDetector(
        onTap: () {
          onHapticLight();
          if (onTap != null) onTap!();
        },
        child: Row(
          children: [
            Icon(icon, color: fontWhite.withValues(alpha: 0.7), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: TextStyle(color: fontWhite.withValues(alpha: 0.9), fontSize: 14)),
            ),
            Icon(Icons.chevron_right_rounded,
                color: fontWhite.withValues(alpha: 0.3), size: 20),
          ],
        ),
      ),
    );
  }
}

class SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isButton;

  const SettingsRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    this.isButton = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: gameYellow, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  color: fontWhite, fontSize: 14, fontWeight: FontWeight.w600)),
        ),
        if (isButton)
          IconButton(
            onPressed: () => onChanged(!value),
            icon: const Icon(Icons.send_rounded, color: gameYellow),
          )
        else
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: gameYellow,
            activeTrackColor: gameYellow.withValues(alpha: 0.3),
            inactiveThumbColor: fontWhite.withValues(alpha: 0.4),
            inactiveTrackColor: fontWhite.withValues(alpha: 0.1),
          ),
      ],
    );
  }
}
