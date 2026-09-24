import 'package:flutter/material.dart';
import '../config/app_theme.dart';

class AudioAvatar extends StatelessWidget {
  final String name;
  final bool isHost;
  final bool isMuted;
  final bool isSpeaking;
  final double radius;
  final VoidCallback? onTap;

  const AudioAvatar({
    super.key,
    required this.name,
    this.isHost = false,
    this.isMuted = true,
    this.isSpeaking = false,
    this.radius = 32,
    this.onTap,
  });

  String get initials {
    if (name.trim().isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              // Pulsing audio ring when speaking
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: (radius * 2) + (isSpeaking ? 12 : 4),
                height: (radius * 2) + (isSpeaking ? 12 : 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSpeaking
                        ? AppTheme.accentColor
                        : (isMuted ? Colors.redAccent.withValues(alpha: 0.5) : AppTheme.primaryColor),
                    width: isSpeaking ? 3 : 1.5,
                  ),
                  boxShadow: isSpeaking
                      ? [
                          BoxShadow(
                            color: AppTheme.accentColor.withValues(alpha: 0.4),
                            blurRadius: 10,
                            spreadRadius: 2,
                          )
                        ]
                      : [],
                ),
              ),
              CircleAvatar(
                radius: radius,
                backgroundColor: isHost ? AppTheme.primaryColor : AppTheme.surfaceDark,
                child: Text(
                  initials,
                  style: TextStyle(
                    fontSize: radius * 0.7,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              // Mic status badge
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isMuted ? Colors.red : AppTheme.success,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.cardDark, width: 2),
                  ),
                  child: Icon(
                    isMuted ? Icons.mic_off : Icons.mic,
                    size: 12,
                    color: Colors.white,
                  ),
                ),
              ),
              // Host badge
              if (isHost)
                Positioned(
                  top: 0,
                  left: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppTheme.warning,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.star,
                      size: 10,
                      color: Colors.black,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
