import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:table_calendar/table_calendar.dart';

void main() {
  runApp(const ProgressTrackerApp());
}

class ProgressTrackerApp extends StatefulWidget {
  const ProgressTrackerApp({super.key});

  @override
  State<ProgressTrackerApp> createState() => _ProgressTrackerAppState();
}

class _ProgressTrackerAppState extends State<ProgressTrackerApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void _toggleTheme() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lightBase = ThemeData(
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF1F3A5F),
        secondary: Color(0xFFE56B6F),
        surface: Color(0xFFF6F1EC),
        background: Color(0xFFF0E9E1),
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Color(0xFF1C1B1F),
        onBackground: Color(0xFF1C1B1F),
        outline: Color(0xFFDED6CC),
      ),
      useMaterial3: true,
    );

    final darkBase = ThemeData(
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF9CC4FF),
        secondary: Color(0xFFF2A9AC),
        surface: Color(0xFF1E1B17),
        background: Color(0xFF151310),
        onPrimary: Color(0xFF0C1C2E),
        onSecondary: Color(0xFF2D1517),
        onSurface: Color(0xFFF3EEE8),
        onBackground: Color(0xFFF3EEE8),
        outline: Color(0xFF3B332C),
      ),
      useMaterial3: true,
    );

    return MaterialApp(
      title: 'Day Tracker',
      themeMode: _themeMode,
      theme: lightBase.copyWith(
        textTheme: GoogleFonts.spaceGroteskTextTheme(lightBase.textTheme),
        scaffoldBackgroundColor: const Color(0xFFF0E9E1),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF0E9E1),
          surfaceTintColor: Color(0xFFF0E9E1),
          elevation: 0,
        ),
      ),
      darkTheme: darkBase.copyWith(
        textTheme: GoogleFonts.spaceGroteskTextTheme(darkBase.textTheme),
        scaffoldBackgroundColor: const Color(0xFF151310),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF151310),
          surfaceTintColor: Color(0xFF151310),
          elevation: 0,
        ),
      ),
      home: ProgressWindowsScreen(
        isDark: _themeMode == ThemeMode.dark,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}

class ProgressWindow {
  ProgressWindow({
    required this.id,
    required this.name,
    Map<DateTime, bool>? entries,
  }) : entries = entries ?? <DateTime, bool>{};

  final String id;
  String name;
  final Map<DateTime, bool> entries;
}

class ProgressWindowsScreen extends StatefulWidget {
  const ProgressWindowsScreen({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
  });

  final bool isDark;
  final VoidCallback onToggleTheme;

  @override
  State<ProgressWindowsScreen> createState() => _ProgressWindowsScreenState();
}

class _ProgressWindowsScreenState extends State<ProgressWindowsScreen> {
  final List<ProgressWindow> _windows = [];
  int _counter = 1;

  Future<void> _addWindow() async {
    final controller = TextEditingController(text: 'Goal $_counter');
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('New Progress Window'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Goal name',
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    if (name == null || name.isEmpty) {
      return;
    }

    setState(() {
      _windows.add(ProgressWindow(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
      ));
      _counter += 1;
    });
  }

  int _countCheckedThisMonth(ProgressWindow window) {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final nextMonth = DateTime(now.year, now.month + 1, 1);
    return window.entries.entries.where((entry) {
      if (!entry.value) {
        return false;
      }
      return entry.key.isAfter(firstDay.subtract(const Duration(days: 1))) &&
          entry.key.isBefore(nextMonth);
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? const [Color(0xFF151310), Color(0xFF1E1B17)]
                : const [Color(0xFFF0E9E1), Color(0xFFE7DCCD)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Day Tracker',
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Track daily goals across multiple windows.',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: colors.onBackground),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: widget.onToggleTheme,
                      icon: Icon(widget.isDark
                          ? Icons.wb_sunny_outlined
                          : Icons.nightlight_round),
                      tooltip: 'Toggle theme',
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _addWindow,
                      icon: const Icon(Icons.add),
                      label: const Text('Add'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: _windows.isEmpty
                      ? _EmptyState(onAdd: _addWindow)
                      : ListView.separated(
                          itemCount: _windows.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final window = _windows[index];
                            final checked = _countCheckedThisMonth(window);
                            return _WindowCard(
                              window: window,
                              checkedThisMonth: checked,
                              onTap: () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        ProgressWindowScreen(window: window),
                                  ),
                                );
                                setState(() {});
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colors.surface.withOpacity(0.85),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colors.outline),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline, size: 48),
            const SizedBox(height: 12),
            Text(
              'Add your first progress window.',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Each window has a calendar with one checkbox per day.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: colors.onSurface),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Create Window'),
            ),
          ],
        ),
      ),
    );
  }
}

class _WindowCard extends StatelessWidget {
  const _WindowCard({
    required this.window,
    required this.checkedThisMonth,
    required this.onTap,
  });

  final ProgressWindow window;
  final int checkedThisMonth;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              height: 52,
              width: 52,
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.calendar_today, color: colors.onPrimary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    window.name,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$checkedThisMonth days checked this month',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: colors.onSurface),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class ProgressWindowScreen extends StatefulWidget {
  const ProgressWindowScreen({super.key, required this.window});

  final ProgressWindow window;

  @override
  State<ProgressWindowScreen> createState() => _ProgressWindowScreenState();
}

class _ProgressWindowScreenState extends State<ProgressWindowScreen> {
  late DateTime _focusedDay;
  WindowView _view = WindowView.calendar;

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
  }

  DateTime _normalize(DateTime day) => DateTime(day.year, day.month, day.day);

  void _toggleDay(DateTime day) {
    final key = _normalize(day);
    setState(() {
      final current = widget.window.entries[key] ?? false;
      widget.window.entries[key] = !current;
    });
  }

  bool _isChecked(DateTime day) {
    final key = _normalize(day);
    return widget.window.entries[key] ?? false;
  }

  Set<DateTime> _checkedSet() {
    return widget.window.entries.entries
        .where((entry) => entry.value)
        .map((entry) => _normalize(entry.key))
        .toSet();
  }

  int _currentStreak() {
    final checked = _checkedSet();
    var streak = 0;
    var day = _normalize(DateTime.now());
    while (checked.contains(day)) {
      streak += 1;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  int _bestStreak() {
    final checked = _checkedSet().toList()..sort();
    if (checked.isEmpty) {
      return 0;
    }
    var best = 1;
    var current = 1;
    for (var i = 1; i < checked.length; i++) {
      final diff = checked[i].difference(checked[i - 1]).inDays;
      if (diff == 1) {
        current += 1;
        if (current > best) {
          best = current;
        }
      } else if (diff > 1) {
        current = 1;
      }
    }
    return best;
  }

  double _monthCompletion() {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final nextMonth = DateTime(now.year, now.month + 1, 1);
    final daysInMonth = nextMonth.difference(firstDay).inDays;
    final checked = widget.window.entries.entries.where((entry) {
      if (!entry.value) {
        return false;
      }
      return entry.key.isAfter(firstDay.subtract(const Duration(days: 1))) &&
          entry.key.isBefore(nextMonth);
    }).length;
    return daysInMonth == 0 ? 0 : checked / daysInMonth;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final monthCompletion = _monthCompletion();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.window.name),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SegmentedButton<WindowView>(
              segments: const [
                ButtonSegment(
                  value: WindowView.calendar,
                  label: Text('Calendar'),
                  icon: Icon(Icons.calendar_today),
                ),
                ButtonSegment(
                  value: WindowView.insights,
                  label: Text('Insights'),
                  icon: Icon(Icons.bar_chart),
                ),
              ],
              selected: <WindowView>{_view},
              onSelectionChanged: (value) {
                setState(() {
                  _view = value.first;
                });
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _view == WindowView.calendar
                    ? Column(
                        key: const ValueKey('calendar'),
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: colors.surface,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 18,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: TableCalendar(
                              firstDay: DateTime.utc(2020, 1, 1),
                              lastDay: DateTime.utc(2035, 12, 31),
                              focusedDay: _focusedDay,
                              calendarFormat: CalendarFormat.month,
                              availableCalendarFormats: const {
                                CalendarFormat.month: 'Month',
                              },
                              rowHeight: 70,
                              daysOfWeekHeight: 24,
                              headerStyle: const HeaderStyle(
                                titleCentered: true,
                                formatButtonVisible: false,
                              ),
                              onPageChanged: (focusedDay) {
                                setState(() {
                                  _focusedDay = focusedDay;
                                });
                              },
                              onDaySelected: (selectedDay, focusedDay) {
                                setState(() {
                                  _focusedDay = focusedDay;
                                });
                                _toggleDay(selectedDay);
                              },
                              calendarBuilders: CalendarBuilders(
                                defaultBuilder: (context, day, focusedDay) {
                                  return _DayCheckboxCell(
                                    day: day,
                                    checked: _isChecked(day),
                                    onToggle: () => _toggleDay(day),
                                  );
                                },
                                todayBuilder: (context, day, focusedDay) {
                                  return _DayCheckboxCell(
                                    day: day,
                                    checked: _isChecked(day),
                                    highlight: true,
                                    onToggle: () => _toggleDay(day),
                                  );
                                },
                                outsideBuilder: (context, day, focusedDay) {
                                  return _DayCheckboxCell(
                                    day: day,
                                    checked: _isChecked(day),
                                    disabled: true,
                                    onToggle: () {},
                                  );
                                },
                                selectedBuilder: (context, day, focusedDay) {
                                  return _DayCheckboxCell(
                                    day: day,
                                    checked: _isChecked(day),
                                    highlight: true,
                                    onToggle: () => _toggleDay(day),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: colors.surface,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.flag_outlined),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Tap any date to mark if you reached your goal.',
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : _InsightsView(
                        key: const ValueKey('insights'),
                        checkedSet: _checkedSet(),
                        currentStreak: _currentStreak(),
                        bestStreak: _bestStreak(),
                        monthCompletion: monthCompletion,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum WindowView { calendar, insights }

class _InsightsView extends StatelessWidget {
  const _InsightsView({
    super.key,
    required this.checkedSet,
    required this.currentStreak,
    required this.bestStreak,
    required this.monthCompletion,
  });

  final Set<DateTime> checkedSet;
  final int currentStreak;
  final int bestStreak;
  final double monthCompletion;

  List<DateTime> _lastDays(int count) {
    final today = DateTime.now();
    return List.generate(
      count,
      (index) => DateTime(today.year, today.month, today.day)
          .subtract(Duration(days: count - 1 - index)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final recentDays = _lastDays(14);
    return SingleChildScrollView(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  label: 'Current streak',
                  value: '$currentStreak days',
                  icon: Icons.local_fire_department_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  label: 'Best streak',
                  value: '$bestStreak days',
                  icon: Icons.emoji_events_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Month completion',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${(monthCompletion * 100).round()}% complete',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: LinearProgressIndicator(
                    value: monthCompletion,
                    minHeight: 12,
                    backgroundColor: colors.outline.withOpacity(0.2),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Last 14 days',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: recentDays.map((day) {
                final checked = checkedSet.contains(day);
                return Container(
                  height: 28,
                  width: 28,
                  decoration: BoxDecoration(
                    color: checked ? colors.secondary : colors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colors.outline),
                  ),
                  child: Center(
                    child: Text(
                      '${day.day}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: checked ? colors.onSecondary : colors.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colors.primary),
          const SizedBox(height: 10),
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _DayCheckboxCell extends StatelessWidget {
  const _DayCheckboxCell({
    required this.day,
    required this.checked,
    required this.onToggle,
    this.highlight = false,
    this.disabled = false,
  });

  final DateTime day;
  final bool checked;
  final VoidCallback onToggle;
  final bool highlight;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textColor = disabled
        ? colors.outline
        : highlight
            ? colors.primary
            : colors.onSurface;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.all(3),
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      decoration: BoxDecoration(
        color: highlight ? colors.primary.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlight ? colors.primary : colors.outline,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${day.day}',
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: textColor, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          IgnorePointer(
            ignoring: disabled,
            child: SizedBox(
              height: 20,
              width: 20,
              child: Checkbox(
                value: checked,
                onChanged: (_) => onToggle(),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
