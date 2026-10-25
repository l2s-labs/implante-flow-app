import 'dart:async';
import 'dart:math';

import '../../domain/clinic_snapshot.dart';
import '../../domain/models.dart';
import '../services/api_feedback.dart';
import '../services/clinic_api.dart';
import '../services/clinical_catalog_codec.dart';
import '../services/clinic_snapshot_codec.dart';
import '../services/local_catalog_store.dart';
import 'clinic_repository.dart';
import 'clinic_state_store.dart';

class ApiClinicRepository implements ClinicRepository {
  ApiClinicRepository({
    required this.api,
    required ClinicSnapshot initial,
    ClinicalCatalog? initialCatalog,
    Future<void> Function(ClinicSnapshot snapshot)? persist,
    CatalogStore? catalogStore,
  })  : _catalog = initialCatalog ?? bundledClinicalCatalog,
        _catalogStore = catalogStore ?? LocalCatalogStore(),
        _local = ClinicStateStore.fromSnapshot(
          initial,
          persist: persist,
          ids: newClinicId,
        ) {
    activeClinicalCatalog = _catalog;
  }

  final ClinicApi api;
  final ClinicStateStore _local;
  final CatalogStore _catalogStore;
  final _failures = StreamController<String>.broadcast();
  final _notices = StreamController<ApiFeedback>.broadcast();
  var _token = '';
  var _epoch = 0;
  var _nameBackfilled = false;
  Future<void> _tail = Future<void>.value();
  Future<String?> Function()? _refreshToken;
  Future<String?>? _refreshInFlight;
  ClinicalCatalog _catalog;
  void Function(ClinicalCatalog catalog)? _applyCatalog;

  Future<void> get settled => _tail;

  @override
  ClinicSnapshot get current => _local.current;

  @override
  ClinicalCatalog get catalog => _catalog;

  @override
  List<String> get delayNoticeFollowUpIds => _local.delayNoticeFollowUpIds;

  @override
  Stream<ClinicSnapshot> watch() => _local.watch();

  @override
  Stream<String> get syncErrors => _failures.stream;

  @override
  Stream<ApiFeedback> get feedback => _notices.stream;

  @override
  void bindUnauthorized(Future<String?> Function() refresh) {
    _refreshToken = refresh;
  }

  @override
  void bindCatalog(void Function(ClinicalCatalog catalog) apply) {
    _applyCatalog = apply;
    apply(_catalog);
  }

  @override
  void applyOverdueNotices() => _local.applyOverdueNotices();

  @override
  void signIn({required String name, required String email, String accessToken = ''}) {
    if (accessToken.isNotEmpty) _token = accessToken;
    _local.signIn(name: sanitizePersonName(name), email: email);
  }

  @override
  void signOut() {
    _token = '';
    _local.signOut();
  }

  @override
  Future<void> refresh() {
    return _enqueue(() async {
      if (_token.isEmpty && _refreshToken == null) return;
      final epoch = _epoch;
      final chart = await _authorized(api.fetchChart);
      if (epoch != _epoch) return;
      _applyChart(chart);
      await _refreshCatalog(epoch);
    });
  }

  @override
  Future<void> refreshCatalog() {
    return _enqueue(() async {
      if (_token.isEmpty && _refreshToken == null) return;
      await _refreshCatalog(_epoch);
    });
  }

  Future<void> _refreshCatalog(int epoch) async {
    try {
      final implants = await _authorized(api.fetchImplantCatalog);
      final grafts = await _authorized(api.fetchGraftCatalog);
      if (epoch != _epoch) return;
      final next = clinicalCatalogFromApi(implants: implants, grafts: grafts);
      _setCatalog(next);
      await _catalogStore.save(next);
    } on ClinicApiException {
      // Mantém cache/bundled; chart já sincronizou.
    }
  }

  void _setCatalog(ClinicalCatalog next) {
    _catalog = next;
    activeClinicalCatalog = next;
    _applyCatalog?.call(next);
  }

  @override
  String allocateId(String prefix) => _local.allocateId(prefix);

  @override
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
  }) {
    _epoch++;
    final patient = _local.createPatient(
      name: name,
      phone: phone,
      email: email,
      cpf: cpf,
      birthDate: birthDate,
      notes: notes,
      guardian: guardian,
      locationIds: locationIds,
      notifyByEmail: notifyByEmail,
      notifyByPhone: notifyByPhone,
    );
    _enqueue(
      () => _authorized((token) => api.createPatient(token, patient)),
      success: 'Paciente salvo com sucesso.',
    );
    return patient;
  }

  @override
  void updatePatient(Patient patient) {
    _epoch++;
    _local.updatePatient(patient);
    final saved = _local.current.patients.firstWhere((item) => item.id == patient.id);
    _enqueue(
      () => _authorized((token) => api.updatePatient(token, saved)),
      success: 'Paciente atualizado com sucesso.',
    );
  }

  @override
  void saveProcedures(List<Procedure> created) {
    _epoch++;
    _local.saveProcedures(created);
    for (final procedure in created) {
      _enqueue(
        () => _authorized((token) => api.createProcedure(token, procedure)),
        success: 'Procedimento salvo com sucesso.',
      );
    }
  }

  @override
  void updateProcedure(Procedure procedure) {
    _epoch++;
    _local.updateProcedure(procedure);
    _enqueue(
      () => _authorized((token) => api.updateProcedure(token, procedure)),
      success: 'Procedimento atualizado com sucesso.',
    );
  }

  @override
  void addPhoto(String procedureId, ClinicPhoto photo) {
    _epoch++;
    _local.addPhoto(procedureId, photo);
    if (photo.path.isEmpty) return;
    _enqueue(() async {
      try {
        await _authorized((token) => api.uploadPhoto(token, procedureId, photo));
      } on ClinicApiException catch (error) {
        // Sem object store a API responde 503; a foto permanece só no aparelho.
        if (error.statusCode == 503) return;
        rethrow;
      }
    });
  }

  @override
  void addVisit({
    required String procedureId,
    required String note,
    required String statusLabel,
  }) {
    _epoch++;
    final before = _visits(procedureId).length;
    _local.addVisit(procedureId: procedureId, note: note, statusLabel: statusLabel);
    final visit = _visits(procedureId).elementAt(before);
    final modality =
        _local.current.procedures.where((item) => item.id == procedureId).firstOrNull?.modality ??
        Modality.implante;
    _enqueue(
      () => _authorized((token) => api.recordVisit(token, procedureId, visit, modality: modality)),
      success: 'Consulta registrada com sucesso.',
    );
  }

  @override
  void completeFollowUp({
    required String followUpId,
    required String note,
    required String statusLabel,
    required ReturnStatus returnStatus,
  }) {
    _epoch++;
    final procedure = _procedureOfFollowUp(followUpId);
    if (procedure == null) return;
    final before = procedure.visits.length;
    _local.completeFollowUp(
      followUpId: followUpId,
      note: note,
      statusLabel: statusLabel,
      returnStatus: returnStatus,
    );
    final updated = _procedureOfFollowUp(followUpId);
    final followUp = updated?.followUps.where((item) => item.id == followUpId).firstOrNull;
    if (followUp != null) {
      _enqueue(() => _authorized((token) => api.updateFollowUp(token, followUp)));
    }
    if (updated != null && updated.visits.length > before) {
      final visit = updated.visits[before];
      _enqueue(
        () => _authorized(
          (token) => api.recordVisit(token, updated.id, visit, modality: updated.modality),
        ),
      );
    }
  }

  @override
  void issueCertificate(
    String procedureId, {
    String? pdfPath,
    int copies = 1,
    String? locationId,
  }) {
    _epoch++;
    _local.issueCertificate(
      procedureId,
      pdfPath: pdfPath,
      copies: copies,
      locationId: locationId,
    );
    _enqueue(() async {
      try {
        await _authorized(
          (token) => api.issueCertificate(
            token,
            procedureId,
            copies: copies,
            locationId: locationId,
          ),
        );
      } on ClinicApiException catch (error) {
        if (error.statusCode == 503) return;
        rethrow;
      }
    });
  }

  @override
  void reprocessStageNotice({required String procedureId, required String noticeId}) {
    _local.reprocessStageNotice(procedureId: procedureId, noticeId: noticeId);
  }

  @override
  void failStageNotice({required String procedureId, required String noticeId}) {
    _local.failStageNotice(procedureId: procedureId, noticeId: noticeId);
  }

  @override
  void updateProfile(DentistProfile profile) {
    _epoch++;
    final previous = _local.current.profile;
    _local.updateProfile(profile);
    _enqueue(
      () async {
        await _authorized((token) => api.updateProfile(token, profile));
        await _syncLocations(previous.locations, profile.locations);
      },
      success: 'Perfil atualizado com sucesso.',
    );
  }

  @override
  InstalledImplant createInstalledImplant(InstalledImplant implant) {
    _epoch++;
    final saved = _local.createInstalledImplant(implant);
    _enqueue(
      () => _authorized((token) => api.createImplant(token, saved)),
      success: 'Implante cadastrado com sucesso.',
    );
    return saved;
  }

  @override
  void updateInstalledImplant(InstalledImplant implant) {
    _epoch++;
    _local.updateInstalledImplant(implant);
    _enqueue(
      () => _authorized((token) => api.updateImplant(token, implant)),
      success: 'Implante atualizado com sucesso.',
    );
  }

  List<Visit> _visits(String procedureId) {
    return _local.current.procedures.firstWhere((item) => item.id == procedureId).visits;
  }

  Procedure? _procedureOfFollowUp(String followUpId) {
    for (final procedure in _local.current.procedures) {
      if (procedure.followUps.any((item) => item.id == followUpId)) return procedure;
    }
    return null;
  }

  Future<void> _syncLocations(List<CareLocation> previous, List<CareLocation> next) async {
    final previousById = {for (final location in previous) location.id: location};
    for (final location in next) {
      final prior = previousById[location.id];
      if (prior == null) {
        await _authorized((token) => api.createLocation(token, location));
      } else if (prior.name != location.name || prior.address != location.address) {
        await _authorized((token) => api.updateLocation(token, location));
      }
    }
    final nextDefault = next.where((location) => location.active && location.isDefault).toList();
    final previousDefault = previous.where((location) => location.active && location.isDefault).toList();
    if (nextDefault.length == 1 &&
        (previousDefault.isEmpty || previousDefault.first.id != nextDefault.first.id)) {
      await _authorized((token) => api.setDefaultLocation(token, nextDefault.first.id));
    }
    for (final location in next) {
      final prior = previousById[location.id];
      if (prior == null) continue;
      if (prior.active && !location.active) {
        await _authorized((token) => api.inactivateLocation(token, location.id));
      } else if (!prior.active && location.active) {
        await _authorized((token) => api.reactivateLocation(token, location.id));
      }
    }
  }

  void _applyChart(Map<String, dynamic> chart) {
    final snapshot = snapshotFromJson({
      'signedIn': true,
      'sequence': _local.current.sequence,
      'profile': chart['profile'],
      'patients': chart['patients'],
      'procedures': chart['procedures'],
    });
    final apiName = sanitizePersonName(snapshot.profile.name);
    final localName = sanitizePersonName(_local.current.profile.name);
    final keptName = apiName.isNotEmpty ? apiName : localName;
    final keptEmail = snapshot.profile.email.trim().isEmpty ? _local.current.profile.email : snapshot.profile.email;
    final profile = snapshot.profile.copyWith(name: keptName, email: keptEmail);
    _local.replaceSnapshot(snapshot.copyWith(profile: profile));
    _local.applyOverdueNotices();
    if (!_nameBackfilled && apiName.isEmpty && keptName.isNotEmpty) {
      _nameBackfilled = true;
      _enqueue(() => _authorized((token) => api.updateProfile(token, profile)));
    }
  }

  Future<T> _authorized<T>(Future<T> Function(String token) call) async {
    var token = _token;
    if (token.isEmpty) {
      token = await _refreshAccessToken() ?? '';
      if (token.isEmpty) {
        throw const ClinicApiException(401, 'Entre de novo para sincronizar o prontuário.');
      }
    }
    try {
      return await call(token);
    } on ClinicApiException catch (error) {
      if (error.statusCode != 401 || _refreshToken == null) rethrow;
      final next = await _refreshAccessToken();
      if (next == null || next.isEmpty) rethrow;
      return call(next);
    }
  }

  Future<String?> _refreshAccessToken() async {
    final inFlight = _refreshInFlight;
    if (inFlight != null) return inFlight;
    final refresh = _refreshToken;
    if (refresh == null) return null;
    final future = () async {
      try {
        final next = await refresh();
        if (next != null && next.isNotEmpty) {
          _token = next;
        }
        return next;
      } finally {
        _refreshInFlight = null;
      }
    }();
    _refreshInFlight = future;
    return future;
  }

  Future<void> _enqueue(Future<void> Function() job, {String? success}) {
    _tail = _tail.then((_) async {
      try {
        await job();
        if (success != null) {
          _notices.add(ApiFeedback.success(success));
        }
      } catch (error) {
        final message = error is ClinicApiException
            ? error.message
            : friendlyApiMessage(0);
        _failures.add(message);
        _notices.add(ApiFeedback.error(message));
        await _reconcile();
      }
    });
    return _tail;
  }

  Future<void> _reconcile() async {
    if (_token.isEmpty) return;
    try {
      final epoch = _epoch;
      final chart = await _authorized(api.fetchChart);
      if (epoch != _epoch) return;
      _applyChart(chart);
    } catch (_) {
      // The first failure is already reported.
    }
  }
}

String newClinicId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
