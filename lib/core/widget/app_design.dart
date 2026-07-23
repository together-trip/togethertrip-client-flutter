import 'package:flutter/material.dart';

class AppColors {
  static const brand = Color(0xFFFF6854);
  static const brandStrong = Color(0xFFE95443);
  static const brandSoft = Color(0xFFFFF0EB);
  static const background = Color(0xFFFFFDF9);
  static const surface = Color(0xFFFFFFFF);
  static const neutralSoft = Color(0xFFF2F4F6);
  static const ink = Color(0xFF191F28);
  static const textSubtle = Color(0xFF4E5968);
  static const textMuted = Color(0xFF8B95A1);
  static const line = Color(0xFFE5E8EB);
  static const lineSoft = Color(0xFFF2F4F6);
  static const success = Color(0xFF20A879);
  static const danger = Color(0xFFD94B4B);
  static const disabled = Color(0xFFE5E8EB);
  static const disabledText = Color(0xFF8B95A1);
}

class AppRadii {
  static const control = Radius.circular(12);
  static const pill = Radius.circular(999);

  static BorderRadius get controlRadius => BorderRadius.circular(12);
  static BorderRadius get sheetRadius =>
      const BorderRadius.vertical(top: control);
}

class AppTextStyles {
  static const screenTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w800,
    color: AppColors.ink,
  );

  static const sectionTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w800,
    color: AppColors.ink,
  );

  static const body = TextStyle(
    fontSize: 14,
    height: 1.5,
    color: Color(0xFF3A3A3A),
  );

  static const caption = TextStyle(fontSize: 12, color: AppColors.textSubtle);
  static const error = TextStyle(color: AppColors.danger, fontSize: 12);
}

class AppButtonStyles {
  static ButtonStyle kakao() {
    return elevatedPrimary().copyWith(
      backgroundColor: const WidgetStatePropertyAll(Color(0xFFFEE500)),
      foregroundColor: const WidgetStatePropertyAll(Colors.black),
    );
  }

  static ButtonStyle primary({double radius = 8}) {
    return FilledButton.styleFrom(
      backgroundColor: AppColors.brand,
      foregroundColor: Colors.white,
      disabledBackgroundColor: AppColors.disabled,
      disabledForegroundColor: AppColors.disabledText,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  static ButtonStyle elevatedPrimary({double radius = 8}) {
    return ElevatedButton.styleFrom(
      backgroundColor: AppColors.brand,
      foregroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  static ButtonStyle outlined({Color sideColor = AppColors.ink}) {
    return OutlinedButton.styleFrom(
      foregroundColor: AppColors.ink,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.controlRadius),
    );
  }

  static ButtonStyle outlinedSelected({required bool selected}) {
    return outlined().copyWith(
      backgroundColor: WidgetStatePropertyAll(
        selected ? AppColors.ink : Colors.white,
      ),
      foregroundColor: WidgetStatePropertyAll(
        selected ? Colors.white : AppColors.ink,
      ),
    );
  }

  static ButtonStyle dangerText() {
    return TextButton.styleFrom(foregroundColor: AppColors.danger);
  }

  static ButtonStyle inkText() {
    return TextButton.styleFrom(foregroundColor: AppColors.ink);
  }

  static ButtonStyle inlineText() {
    return TextButton.styleFrom(
      padding: EdgeInsets.zero,
      minimumSize: const Size(0, 32),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class AppIconButtonStyles {
  static ButtonStyle filledInk() {
    return IconButton.styleFrom(
      backgroundColor: AppColors.ink,
      foregroundColor: Colors.white,
    );
  }

  static ButtonStyle neutral({Size size = const Size(32, 32)}) {
    return IconButton.styleFrom(
      backgroundColor: AppColors.neutralSoft,
      foregroundColor: AppColors.textSubtle,
      fixedSize: size,
      minimumSize: size,
    );
  }
}

class AppTheme {
  static ThemeData light() {
    const colorScheme = ColorScheme.light(
      primary: AppColors.brand,
      onPrimary: Colors.white,
      primaryContainer: AppColors.brandSoft,
      onPrimaryContainer: AppColors.brandStrong,
      secondary: AppColors.ink,
      onSecondary: Colors.white,
      error: AppColors.danger,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      outline: AppColors.line,
    );

    final base = ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      fontFamily: 'Pretendard',
      scaffoldBackgroundColor: AppColors.background,
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.ink,
        displayColor: AppColors.ink,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.lineSoft,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.neutralSoft,
        border: OutlineInputBorder(
          borderRadius: AppRadii.controlRadius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.controlRadius,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.controlRadius,
          borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.brand,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.ink,
        contentTextStyle: TextStyle(
          fontFamily: 'Pretendard',
          color: Colors.white,
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class AppInputDecorations {
  static InputDecoration filled({
    String? labelText,
    String? hintText,
    Widget? prefixIcon,
    String? suffixText,
    TextStyle? suffixStyle,
    bool isDense = false,
    bool alignLabelWithHint = false,
    EdgeInsetsGeometry? contentPadding,
    String? counterText,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: prefixIcon,
      suffixText: suffixText,
      suffixStyle: suffixStyle,
      counterText: counterText,
      alignLabelWithHint: alignLabelWithHint,
      isDense: isDense,
      filled: true,
      fillColor: AppColors.surface,
      contentPadding:
          contentPadding ??
          const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: AppRadii.controlRadius,
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadii.controlRadius,
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadii.controlRadius,
        borderSide: BorderSide.none,
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: AppRadii.controlRadius,
        borderSide: BorderSide.none,
      ),
    );
  }
}

class AppSheetHandle extends StatelessWidget {
  const AppSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.line,
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
  }
}

class AppErrorText extends StatelessWidget {
  final String message;
  final TextAlign? textAlign;

  const AppErrorText(this.message, {super.key, this.textAlign});

  @override
  Widget build(BuildContext context) {
    return Text(message, textAlign: textAlign, style: AppTextStyles.error);
  }
}

Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool useSafeArea = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: useSafeArea,
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: AppRadii.sheetRadius),
    builder: builder,
  );
}
