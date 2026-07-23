import 'package:flutter/material.dart';

import 'app_design.dart';

Future<DateTime?> showTogetherTripDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String helpText = '날짜 선택',
}) {
  return showDatePicker(
    context: context,
    locale: const Locale('ko'),
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
    helpText: helpText,
    cancelText: '취소',
    confirmText: '확인',
    fieldLabelText: '날짜',
    fieldHintText: 'yyyy. mm. dd.',
    errorFormatText: '날짜 형식을 확인해 주세요.',
    errorInvalidText: '선택할 수 없는 날짜입니다.',
    builder: _datePickerBuilder,
  );
}

Future<DateTimeRange?> showTogetherTripDateRangePicker({
  required BuildContext context,
  required DateTimeRange initialDateRange,
  required DateTime firstDate,
  required DateTime lastDate,
  String helpText = '기간 선택',
}) {
  return showDateRangePicker(
    context: context,
    locale: const Locale('ko'),
    initialDateRange: initialDateRange,
    firstDate: firstDate,
    lastDate: lastDate,
    helpText: helpText,
    cancelText: '취소',
    confirmText: '확인',
    saveText: '적용',
    fieldStartLabelText: '시작일',
    fieldEndLabelText: '종료일',
    fieldStartHintText: 'yyyy. mm. dd.',
    fieldEndHintText: 'yyyy. mm. dd.',
    errorFormatText: '날짜 형식을 확인해 주세요.',
    errorInvalidText: '선택할 수 없는 날짜입니다.',
    errorInvalidRangeText: '종료일은 시작일 이후여야 합니다.',
    builder: _datePickerBuilder,
  );
}

Widget _datePickerBuilder(BuildContext context, Widget? child) {
  final baseTheme = Theme.of(context);
  return Theme(
    data: baseTheme.copyWith(
      colorScheme: const ColorScheme.light(
        primary: AppColors.ink,
        onPrimary: Colors.white,
        surface: Colors.white,
        onSurface: AppColors.ink,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        headerBackgroundColor: AppColors.ink,
        headerForegroundColor: Colors.white,
        dayShape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        todayBorder: const BorderSide(color: AppColors.ink),
      ),
      textButtonTheme: TextButtonThemeData(style: AppButtonStyles.inkText()),
    ),
    child: child ?? const SizedBox.shrink(),
  );
}
