import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:implate_flow/ui/core/phone_input_formatter.dart';

void main() {
  test('máscara muda entre fixo e celular e permite apagar', () {
    expect(formatContactPhone('2133334444'), '(21) 3333 4444');
    expect(formatContactPhone('21999998888'), '(21) 9 9999 8888');
    const formatter = ContactPhoneInputFormatter();
    const old = TextEditingValue(
      text: '(21) 3333 4',
      selection: TextSelection.collapsed(offset: 11),
    );
    const incoming = TextEditingValue(
      text: '(21) 33334',
      selection: TextSelection.collapsed(offset: 9),
    );
    expect(formatter.formatEditUpdate(old, incoming).text, '(21) 3334');
  });
}
