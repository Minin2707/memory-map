import 'package:memory_map/features/memory/domain/memory_date.dart';
import 'package:memory_map/l10n/app_localizations.dart';

String formatMemoryDate(AppLocalizations l10n, MemoryDate date) {
  final locale = l10n.localeName;
  if (locale.startsWith('ru')) {
    return '${date.day} ${_ruMonths[date.month - 1]} ${date.year} г.';
  }

  return '${_enMonths[date.month - 1]} ${date.day}, ${date.year}';
}

const List<String> _enMonths = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

const List<String> _ruMonths = <String>[
  'янв.',
  'февр.',
  'мар.',
  'апр.',
  'мая',
  'июн.',
  'июл.',
  'авг.',
  'сент.',
  'окт.',
  'нояб.',
  'дек.',
];
