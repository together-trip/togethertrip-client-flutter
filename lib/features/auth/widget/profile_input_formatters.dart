import 'package:flutter/services.dart';

String digitsOnly(String value) {
  return value.replaceAll(RegExp(r'\D'), '');
}

class BirthDateInputFormatter extends TextInputFormatter {
  const BirthDateInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = digitsOnly(newValue.text);
    final limited = digits.length > 8 ? digits.substring(0, 8) : digits;
    final formatted = _formatBirthDate(limited);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _formatBirthDate(String digits) {
    if (digits.length <= 4) return digits;
    if (digits.length <= 6) {
      return '${digits.substring(0, 4)}.${digits.substring(4)}';
    }

    return '${digits.substring(0, 4)}.${digits.substring(4, 6)}.${digits.substring(6)}';
  }
}

class PhoneNumberInputFormatter extends TextInputFormatter {
  const PhoneNumberInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = digitsOnly(newValue.text);
    final limited = digits.length > 11 ? digits.substring(0, 11) : digits;
    final formatted = _formatPhoneNumber(limited);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _formatPhoneNumber(String digits) {
    if (digits.length <= 3) return digits;
    if (digits.length <= 7) {
      return '${digits.substring(0, 3)}-${digits.substring(3)}';
    }

    return '${digits.substring(0, 3)}-${digits.substring(3, 7)}-${digits.substring(7)}';
  }
}
