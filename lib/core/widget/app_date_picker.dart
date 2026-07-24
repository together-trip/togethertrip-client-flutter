import 'package:flutter/material.dart';

import 'app_design.dart';

Future<DateTime?> showTogetherTripDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String helpText = '날짜 선택',
}) {
  return showAppBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _SingleDatePickerSheet(
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: helpText,
    ),
  );
}

Future<DateTimeRange?> showTogetherTripDateRangePicker({
  required BuildContext context,
  required DateTimeRange initialDateRange,
  required DateTime firstDate,
  required DateTime lastDate,
  String title = '기간 선택',
  String helpText = '기간 선택',
  String confirmText = '기간 적용',
  bool showDurationInConfirm = false,
  String startLabel = '시작',
  String endLabel = '종료',
  String pendingEndText = '종료일을 선택해 주세요',
}) {
  return Navigator.of(context).push<DateTimeRange>(
    MaterialPageRoute<DateTimeRange>(
      fullscreenDialog: true,
      builder: (_) => _DateRangePickerScreen(
        initialDateRange: initialDateRange,
        firstDate: firstDate,
        lastDate: lastDate,
        title: title,
        helpText: helpText,
        confirmText: confirmText,
        showDurationInConfirm: showDurationInConfirm,
        startLabel: startLabel,
        endLabel: endLabel,
        pendingEndText: pendingEndText,
      ),
    ),
  );
}

class _SingleDatePickerSheet extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final String helpText;

  const _SingleDatePickerSheet({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.helpText,
  });

  @override
  State<_SingleDatePickerSheet> createState() => _SingleDatePickerSheetState();
}

class _SingleDatePickerSheetState extends State<_SingleDatePickerSheet> {
  late DateTime _selectedDate;
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    _selectedDate = _clampDate(
      _dateOnly(widget.initialDate),
      _dateOnly(widget.firstDate),
      _dateOnly(widget.lastDate),
    );
    _visibleMonth = _monthOf(_selectedDate);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppSheetHandle(),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.helpText,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatKoreanDate(_selectedDate),
                        key: const ValueKey('singleDatePickerSelection'),
                        style: AppTextStyles.sectionTitle,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '닫기',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _MonthCalendar(
              keyPrefix: 'datePicker',
              visibleMonth: _visibleMonth,
              firstDate: widget.firstDate,
              lastDate: widget.lastDate,
              selectedStart: _selectedDate,
              selectedEnd: _selectedDate,
              onMonthChanged: (month) => setState(() => _visibleMonth = month),
              onDateSelected: (date) => setState(() => _selectedDate = date),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                key: const ValueKey('confirmSingleDateButton'),
                onPressed: () => Navigator.of(context).pop(_selectedDate),
                style: AppButtonStyles.elevatedPrimary(),
                child: const Text(
                  '이 날짜 선택',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateRangePickerScreen extends StatefulWidget {
  final DateTimeRange initialDateRange;
  final DateTime firstDate;
  final DateTime lastDate;
  final String title;
  final String helpText;
  final String confirmText;
  final bool showDurationInConfirm;
  final String startLabel;
  final String endLabel;
  final String pendingEndText;

  const _DateRangePickerScreen({
    required this.initialDateRange,
    required this.firstDate,
    required this.lastDate,
    required this.title,
    required this.helpText,
    required this.confirmText,
    required this.showDurationInConfirm,
    required this.startLabel,
    required this.endLabel,
    required this.pendingEndText,
  });

  @override
  State<_DateRangePickerScreen> createState() => _DateRangePickerScreenState();
}

class _DateRangePickerScreenState extends State<_DateRangePickerScreen> {
  late DateTime _startDate;
  DateTime? _endDate;
  late DateTime _visibleMonth;
  bool _selectingEnd = false;

  @override
  void initState() {
    super.initState();
    final firstDate = _dateOnly(widget.firstDate);
    final lastDate = _dateOnly(widget.lastDate);
    _startDate = _clampDate(
      _dateOnly(widget.initialDateRange.start),
      firstDate,
      lastDate,
    );
    final initialEnd = _clampDate(
      _dateOnly(widget.initialDateRange.end),
      firstDate,
      lastDate,
    );
    _endDate = initialEnd.isBefore(_startDate) ? _startDate : initialEnd;
    _visibleMonth = _monthOf(_startDate);
  }

  void _selectDate(DateTime date) {
    setState(() {
      if (!_selectingEnd) {
        _startDate = date;
        _endDate = null;
        _selectingEnd = true;
        return;
      }
      if (date.isBefore(_startDate)) {
        _startDate = date;
        _endDate = null;
        return;
      }
      _endDate = date;
      _selectingEnd = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final endDate = _endDate;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          tooltip: '뒤로',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        title: Text(widget.title),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.helpText,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _RangeDateSummary(
                          label: widget.startLabel,
                          date: _startDate,
                          active: !_selectingEnd,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                          color: AppColors.textMuted,
                        ),
                      ),
                      Expanded(
                        child: _RangeDateSummary(
                          label: widget.endLabel,
                          date: endDate,
                          active: _selectingEnd,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _MonthCalendar(
                  keyPrefix: 'dateRangePicker',
                  visibleMonth: _visibleMonth,
                  firstDate: widget.firstDate,
                  lastDate: widget.lastDate,
                  selectedStart: _startDate,
                  selectedEnd: endDate,
                  onMonthChanged: (month) =>
                      setState(() => _visibleMonth = month),
                  onDateSelected: _selectDate,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  key: const ValueKey('confirmDateRangeButton'),
                  onPressed: endDate == null
                      ? null
                      : () => Navigator.of(
                          context,
                        ).pop(DateTimeRange(start: _startDate, end: endDate)),
                  style: AppButtonStyles.elevatedPrimary(),
                  child: Text(
                    endDate == null
                        ? widget.pendingEndText
                        : widget.showDurationInConfirm
                        ? '${endDate.difference(_startDate).inDays}박 ${endDate.difference(_startDate).inDays + 1}일 ${widget.confirmText}'
                        : widget.confirmText,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RangeDateSummary extends StatelessWidget {
  final String label;
  final DateTime? date;
  final bool active;

  const _RangeDateSummary({
    required this.label,
    required this.date,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppMotion.fast,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 9),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.controlRadius,
        border: Border(
          bottom: BorderSide(
            color: active ? AppColors.brand : AppColors.line,
            width: active ? 2 : 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.caption),
          const SizedBox(height: 3),
          Text(
            date == null ? '선택해 주세요' : _formatCompactKoreanDate(date!),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: date == null ? AppColors.textMuted : AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthCalendar extends StatelessWidget {
  final String keyPrefix;
  final DateTime visibleMonth;
  final DateTime firstDate;
  final DateTime lastDate;
  final DateTime selectedStart;
  final DateTime? selectedEnd;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime> onDateSelected;

  const _MonthCalendar({
    required this.keyPrefix,
    required this.visibleMonth,
    required this.firstDate,
    required this.lastDate,
    required this.selectedStart,
    required this.selectedEnd,
    required this.onMonthChanged,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedFirstDate = _dateOnly(firstDate);
    final normalizedLastDate = _dateOnly(lastDate);
    final firstMonth = _monthOf(normalizedFirstDate);
    final lastMonth = _monthOf(normalizedLastDate);
    final previousMonth = DateTime(visibleMonth.year, visibleMonth.month - 1);
    final nextMonth = DateTime(visibleMonth.year, visibleMonth.month + 1);
    final canGoPrevious = !previousMonth.isBefore(firstMonth);
    final canGoNext = !nextMonth.isAfter(lastMonth);
    final firstWeekdayOffset = visibleMonth.weekday % 7;
    final dayCount = DateUtils.getDaysInMonth(
      visibleMonth.year,
      visibleMonth.month,
    );
    final cellCount = ((firstWeekdayOffset + dayCount + 6) ~/ 7) * 7;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${visibleMonth.year}년 ${visibleMonth.month}월',
                    style: AppTextStyles.sectionTitle,
                  ),
                ),
                IconButton(
                  tooltip: '이전 달',
                  onPressed: canGoPrevious
                      ? () => onMonthChanged(previousMonth)
                      : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                IconButton(
                  tooltip: '다음 달',
                  onPressed: canGoNext ? () => onMonthChanged(nextMonth) : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Row(
              children: [
                _WeekdayLabel('일'),
                _WeekdayLabel('월'),
                _WeekdayLabel('화'),
                _WeekdayLabel('수'),
                _WeekdayLabel('목'),
                _WeekdayLabel('금'),
                _WeekdayLabel('토'),
              ],
            ),
            const SizedBox(height: 4),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1,
              ),
              itemCount: cellCount,
              itemBuilder: (context, index) {
                final day = index - firstWeekdayOffset + 1;
                if (day < 1 || day > dayCount) return const SizedBox.shrink();
                final date = DateTime(
                  visibleMonth.year,
                  visibleMonth.month,
                  day,
                );
                final enabled =
                    !date.isBefore(normalizedFirstDate) &&
                    !date.isAfter(normalizedLastDate);
                final isStart = _isSameDate(date, selectedStart);
                final isEnd =
                    selectedEnd != null && _isSameDate(date, selectedEnd!);
                final isInRange =
                    selectedEnd != null &&
                    date.isAfter(selectedStart) &&
                    date.isBefore(selectedEnd!);
                final isToday = _isSameDate(date, DateTime.now());
                return _CalendarDay(
                  key: ValueKey(
                    '$keyPrefix-${date.year}-${_twoDigits(date.month)}-${_twoDigits(date.day)}',
                  ),
                  date: date,
                  enabled: enabled,
                  isEndpoint: isStart || isEnd,
                  isInRange: isInRange,
                  isToday: isToday,
                  onTap: () => onDateSelected(date),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekdayLabel extends StatelessWidget {
  final String label;

  const _WeekdayLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            label,
            style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
          ),
        ),
      ),
    );
  }
}

class _CalendarDay extends StatelessWidget {
  final DateTime date;
  final bool enabled;
  final bool isEndpoint;
  final bool isInRange;
  final bool isToday;
  final VoidCallback onTap;

  const _CalendarDay({
    super.key,
    required this.date,
    required this.enabled,
    required this.isEndpoint,
    required this.isInRange,
    required this.isToday,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isEndpoint
        ? AppColors.brand
        : isInRange
        ? AppColors.brandSoft
        : Colors.transparent;
    final foregroundColor = !enabled
        ? AppColors.disabledText
        : isEndpoint
        ? Colors.white
        : isInRange
        ? AppColors.brandStrong
        : AppColors.ink;

    return Semantics(
      label: '${date.year}년 ${date.month}월 ${date.day}일',
      selected: isEndpoint || isInRange,
      button: true,
      enabled: enabled,
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: enabled ? onTap : null,
          child: AnimatedContainer(
            duration: AppMotion.fast,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(10),
              border: isToday && !isEndpoint
                  ? Border.all(color: AppColors.brand)
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              '${date.day}',
              style: TextStyle(
                color: foregroundColor,
                fontSize: 14,
                fontWeight: isEndpoint || isToday
                    ? FontWeight.w800
                    : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

DateTime _monthOf(DateTime date) => DateTime(date.year, date.month);

DateTime _clampDate(DateTime date, DateTime firstDate, DateTime lastDate) {
  if (date.isBefore(firstDate)) return firstDate;
  if (date.isAfter(lastDate)) return lastDate;
  return date;
}

bool _isSameDate(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;

String _formatKoreanDate(DateTime date) =>
    '${date.year}년 ${date.month}월 ${date.day}일 ${_weekdayLabel(date)}';

String _formatCompactKoreanDate(DateTime date) =>
    '${date.month}월 ${date.day}일 ${_weekdayLabel(date)}';

String _weekdayLabel(DateTime date) {
  const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
  return '(${weekdays[date.weekday - 1]})';
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');
