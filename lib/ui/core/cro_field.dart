import 'package:flutter/services.dart';

import '../../domain/certificate.dart';

/// Exibe o conteúdo editável após o prefixo fixo CRO-.
String formatCroInput(String value) {
  final canonical = normalizeCro(value);
  if (canonical != null) return canonical;
  final text = value.toUpperCase().replaceFirst(
    RegExp(r'^\s*CRO[\s\-/:]*'),
    '',
  );
  final letters = RegExp(r'[A-Z]')
      .allMatches(text)
      .map((m) => m.group(0)!)
      .take(2)
      .join();
  final digits = RegExp(r'\d').allMatches(text).map((m) => m.group(0)!).join();
  if (letters.isEmpty) return digits;
  if (digits.isEmpty) return letters;
  return '$letters $digits';
}

class CroInputFormatter extends TextInputFormatter {
  const CroInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final value = formatCroInput(newValue.text);
    final end = newValue.selection.extentOffset.clamp(0, newValue.text.length);
    final beforeCursor = formatCroInput(newValue.text.substring(0, end));
    return TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(
        offset: beforeCursor.length.clamp(0, value.length),
      ),
    );
  }
}
