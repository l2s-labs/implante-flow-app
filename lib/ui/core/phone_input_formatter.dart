import 'package:flutter/services.dart';

import '../../domain/models.dart';

String formatContactPhone(String value) {
  final digits = brazilianPhoneDigits(value);
  if (digits.isEmpty) return '';
  if (digits.length <= 2) return '($digits';
  final area = digits.substring(0, 2);
  final rest = digits.substring(2);
  if (digits.length <= 10) {
    if (rest.length <= 4) return '($area) $rest';
    return '($area) ${rest.substring(0, 4)} ${rest.substring(4)}';
  }
  return '($area) ${rest.substring(0, 1)} ${rest.substring(1, 5)} ${rest.substring(5)}';
}

class ContactPhoneInputFormatter extends TextInputFormatter {
  const ContactPhoneInputFormatter();
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final masked = applyDigitMask(
      previous: oldValue.text,
      incoming: newValue.text,
      cursor: newValue.selection.extentOffset,
      format: formatContactPhone,
    );
    return TextEditingValue(
      text: masked.text,
      selection: TextSelection.collapsed(
        offset: masked.offset.clamp(0, masked.text.length),
      ),
    );
  }
}
