import 'certificate.dart';
import 'models.dart';

const _brazilianStates = {
  'AC',
  'AL',
  'AP',
  'AM',
  'BA',
  'CE',
  'DF',
  'ES',
  'GO',
  'MA',
  'MT',
  'MS',
  'MG',
  'PA',
  'PB',
  'PR',
  'PE',
  'PI',
  'RJ',
  'RN',
  'RS',
  'RO',
  'RR',
  'SC',
  'SP',
  'SE',
  'TO',
};

bool firstStepsValidCro(String value) {
  final normalized = normalizeCro(value);
  return normalized != null &&
      _brazilianStates.contains(normalized.substring(0, 2));
}

bool firstStepsValidPhone(String value) {
  var digits = digitsOnly(value);
  if (digits.startsWith('55') && (digits.length == 12 || digits.length == 13)) {
    digits = digits.substring(2);
  }
  return (digits.length == 10 || digits.length == 11) &&
      validBrazilianAreaCodes.contains(digits.substring(0, 2)) &&
      (digits.length != 11 || digits[2] == '9');
}
