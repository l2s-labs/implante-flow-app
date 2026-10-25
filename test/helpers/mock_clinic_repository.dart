import 'package:implate_flow/data/repositories/clinic_state_store.dart';
import 'package:implate_flow/domain/clinic_snapshot.dart';

import 'mock_clinic_service.dart';

/// Repositório local alimentado pelo snapshot de demonstração — só para testes.
class MockClinicRepository extends ClinicStateStore {
  MockClinicRepository(
    MockClinicService service, {
    Future<void> Function(ClinicSnapshot snapshot)? persist,
  }) : super.fromSnapshot(service.load(), persist: persist);

  MockClinicRepository.fromSnapshot(
    ClinicSnapshot snapshot, {
    Future<void> Function(ClinicSnapshot snapshot)? persist,
    String Function()? ids,
  }) : super.fromSnapshot(snapshot, persist: persist, ids: ids);
}
