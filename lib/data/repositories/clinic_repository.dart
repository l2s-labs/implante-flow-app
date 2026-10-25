import '../../domain/clinic_snapshot.dart';
import '../../domain/models.dart';
import '../services/api_feedback.dart';

abstract class ClinicRepository {
  Stream<ClinicSnapshot> watch();

  Stream<String> get syncErrors => const Stream<String>.empty();

  Stream<ApiFeedback> get feedback => const Stream<ApiFeedback>.empty();

  ClinicSnapshot get current;

  ClinicalCatalog get catalog => activeClinicalCatalog;

  List<String> get delayNoticeFollowUpIds;

  void applyOverdueNotices();

  void bindUnauthorized(Future<String?> Function() refresh) {}

  void bindCatalog(void Function(ClinicalCatalog catalog) apply) {}

  void signIn({required String name, required String email, String accessToken = ''});

  void signOut();

  Future<void> refresh() async {}

  /// Atualiza fabricantes/modelos/tamanhos (e enxertos) a partir da API.
  Future<void> refreshCatalog() async {}

  Patient createPatient({
    required String name,
    required String phone,
    String email = '',
    String cpf = '',
    required DateTime birthDate,
    String notes = '',
    String guardian = '',
    List<String> locationIds = const [],
    bool notifyByEmail = false,
    bool notifyByPhone = false,
  });

  void updatePatient(Patient patient);

  void saveProcedures(List<Procedure> created);

  void updateProcedure(Procedure procedure);

  void addPhoto(String procedureId, ClinicPhoto photo);

  void addVisit({
    required String procedureId,
    required String note,
    required String statusLabel,
  });

  void completeFollowUp({
    required String followUpId,
    required String note,
    required String statusLabel,
    required ReturnStatus returnStatus,
  });

  void issueCertificate(
    String procedureId, {
    String? pdfPath,
    int copies = 1,
    String? locationId,
  });

  void reprocessStageNotice({required String procedureId, required String noticeId});

  void failStageNotice({required String procedureId, required String noticeId});

  void updateProfile(DentistProfile profile);

  InstalledImplant createInstalledImplant(InstalledImplant implant);

  void updateInstalledImplant(InstalledImplant implant);

  String allocateId(String prefix);
}
