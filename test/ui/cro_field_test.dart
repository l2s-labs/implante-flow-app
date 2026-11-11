import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:implate_flow/ui/core/cro_field.dart';
import 'package:implate_flow/domain/certificate.dart';

void main() {
  test('formata UF e número ao digitar e colar com prefixo', () {
    const formatter = CroInputFormatter();
    TextEditingValue edit(String text) => TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    expect(formatter.formatEditUpdate(edit('RJ'), edit('RJ4')).text, 'RJ 4');
    expect(
      formatter.formatEditUpdate(edit(''), edit('cro-rj 44731')).text,
      'RJ 44731',
    );
    expect(formatCroInput('44731/RJ'), 'RJ 44731');
    expect(normalizeCro('CRO-${formatCroInput('rj44731')}'), 'RJ 44731');
  });
}
