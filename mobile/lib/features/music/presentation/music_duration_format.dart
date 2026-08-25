String formatMusicDuration(int durationSeconds) {
  final safeSeconds = durationSeconds < 0 ? 0 : durationSeconds;
  final hours = safeSeconds ~/ 3600;
  final minutes = (safeSeconds % 3600) ~/ 60;
  final seconds = safeSeconds % 60;
  final secondsText = seconds.toString().padLeft(2, '0');

  if (hours == 0) {
    return '$minutes:$secondsText';
  }

  final minutesText = minutes.toString().padLeft(2, '0');
  return '$hours:$minutesText:$secondsText';
}
