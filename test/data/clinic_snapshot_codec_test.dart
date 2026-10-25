import 'package:flutter_test/flutter_test.dart';
import 'package:implate_flow/data/services/clinic_snapshot_codec.dart';
import '../helpers/mock_clinic_service.dart';

void main() {
  test('snapshot JSON round-trip keeps patients and photos', () {
    final original = MockClinicService().load();
    final restored = decodeClinicSnapshot(encodeClinicSnapshot(original));
    expect(restored.patients.length, original.patients.length);
    expect(restored.procedures.length, original.procedures.length);
    expect(restored.procedures.first.photos.first.caption, isNotEmpty);
    expect(restored.sequence, original.sequence);
  });
}
