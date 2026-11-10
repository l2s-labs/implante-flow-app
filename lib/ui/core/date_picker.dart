import 'package:flutter/material.dart';

/// Locale forçado nos DatePickers do app (L2S-69).
///
/// MaterialApp também fixa `pt_BR`; o parâmetro `locale` do picker garante
/// mês/dias em português mesmo se o aparelho estiver em outro idioma.
const Locale kAppLocalePtBr = Locale('pt', 'BR');

/// Abre o DatePicker nativo com mês/dias em português.
Future<DateTime?> showAppDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  return showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
    locale: kAppLocalePtBr,
  );
}
