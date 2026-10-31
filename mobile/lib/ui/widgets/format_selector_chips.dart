import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../theme/spotify_theme.dart';

class FormatSelectorChips extends StatelessWidget {
  final String selectedFormat;
  final ValueChanged<String> onFormatChanged;

  const FormatSelectorChips({
    Key? key,
    required this.selectedFormat,
    required this.onFormatChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _buildChip(
          label: 'MP3 (320 kbps)',
          value: AppConstants.formatMp3,
          badge: 'Рекомендуется',
        ),
        const SizedBox(width: 12),
        _buildChip(
          label: 'FLAC (Lossless)',
          value: AppConstants.formatFlac,
          badge: 'Hi-Fi',
        ),
      ],
    );
  }

  Widget _buildChip({
    required String label,
    required String value,
    required String badge,
  }) {
    final isSelected = selectedFormat == value;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => onFormatChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? SpotifyTheme.spotifyGreen.withOpacity(0.15)
                : SpotifyTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? SpotifyTheme.spotifyGreen
                  : SpotifyTheme.borderColor,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: isSelected
                          ? SpotifyTheme.textPrimary
                          : SpotifyTheme.textSecondary,
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                  if (isSelected)
                    const Icon(
                      Icons.check_circle,
                      color: SpotifyTheme.spotifyGreen,
                      size: 16,
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? SpotifyTheme.spotifyGreen.withOpacity(0.25)
                      : Colors.white10,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    color: isSelected
                        ? SpotifyTheme.spotifyGreen
                        : SpotifyTheme.textSecondary,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
