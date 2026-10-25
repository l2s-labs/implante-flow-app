import 'package:flutter/foundation.dart';

import '../../data/repositories/clinic_repository.dart';
import '../../domain/models.dart';

class GraftDraft {
  GraftOrigin origin = GraftOrigin.biomaterial;
  GraftProcessing? processing;
  GraftPresentation? presentation;
  String manufacturer = '';
  String model = '';
  String productType = '';
  String granulometry = '';
  String size = '';
  String lot = '';
  String anvisa = '';
  DateTime? manufacturedOn;
  DateTime? expiresOn;
  String donorSite = '';

  GraftMaterialChoice? get materialChoice => graftMaterialChoice(origin, processing);

  GraftDraft copy() {
    return GraftDraft()
      ..origin = origin
      ..processing = processing
      ..presentation = presentation
      ..manufacturer = manufacturer
      ..model = model
      ..productType = productType
      ..granulometry = granulometry
      ..size = size
      ..lot = lot
      ..anvisa = anvisa
      ..manufacturedOn = manufacturedOn
      ..expiresOn = expiresOn
      ..donorSite = donorSite;
  }

  void selectMaterial(GraftMaterialChoice choice) {
    presentation = null;
    granulometry = '';
    if (choice == GraftMaterialChoice.autogeno) {
      origin = GraftOrigin.autogeno;
      processing = null;
      manufacturer = '';
      model = '';
      productType = '';
      size = '';
      lot = '';
      anvisa = '';
      manufacturedOn = null;
      expiresOn = null;
      return;
    }
    origin = GraftOrigin.biomaterial;
    processing = GraftProcessing.liofilizado;
    donorSite = '';
    productType = graftProductOf(manufacturer, model)?.type ?? '';
  }

  void selectManufacturer(String value) {
    manufacturer = value;
    model = '';
    productType = '';
    presentation = null;
    granulometry = '';
  }

  void selectModel(String value) {
    model = value;
    final product = graftProductOf(manufacturer, value);
    productType = product?.type ?? '';
    if (presentation != null &&
        product != null &&
        !product.presentations.contains(presentation)) {
      presentation = null;
    }
    _clearGranulometryUnlessListed(product);
  }

  void selectPresentation(GraftPresentation value) {
    final product = graftProductOf(manufacturer, model);
    if (processing == GraftProcessing.liofilizado &&
        product != null &&
        !product.presentations.contains(value)) {
      return;
    }
    presentation = value;
    if (value == GraftPresentation.bloco) {
      granulometry = '';
      return;
    }
    _clearGranulometryUnlessListed(graftProductOf(manufacturer, model));
  }

  void selectGranulometry(String value) {
    if (presentation != GraftPresentation.po) return;
    final product = graftProductOf(manufacturer, model);
    if (product != null && !product.granulometries.contains(value)) return;
    granulometry = value;
  }

  void _clearGranulometryUnlessListed(GraftProduct? product) {
    if (presentation != GraftPresentation.po) {
      granulometry = '';
      return;
    }
    if (product != null && !product.granulometries.contains(granulometry)) {
      granulometry = '';
    }
  }

  GraftMaterial toMaterial() {
    return GraftMaterial(
      origin: origin,
      processing: processing,
      presentation: presentation,
      manufacturer: manufacturer,
      model: model,
      productType: productType,
      granulometry: granulometry,
      size: size,
      lot: lot,
      anvisa: anvisa,
      manufacturedOn: manufacturedOn,
      expiresOn: expiresOn,
      donorSite: donorSite,
    );
  }

  static GraftDraft fromMaterial(GraftMaterial graft) {
    return GraftDraft()
      ..origin = graft.origin
      ..processing = graft.processing
      ..presentation = graft.presentation
      ..manufacturer = graft.manufacturer
      ..model = graft.model
      ..productType = graft.productType
      ..granulometry = graft.granulometry
      ..size = graft.size
      ..lot = graft.lot
      ..anvisa = graft.anvisa
      ..manufacturedOn = graft.manufacturedOn
      ..expiresOn = graft.expiresOn
      ..donorSite = graft.donorSite;
  }
}

class PieceDraft {
  String manufacturer = '';
  String model = '';
  String reference = '';
  String size = '';
  String lot = '';
  String anvisa = '';
  DateTime? manufacturedOn;
  DateTime? expiresOn;
  bool withGraft = false;
  List<GraftDraft> grafts = [GraftDraft()];

  static PieceDraft fromSite(ToothSite site) {
    final piece = site.piece;
    return PieceDraft()
      ..manufacturer = piece?.manufacturer ?? ''
      ..model = piece?.model ?? ''
      ..reference = piece?.reference ?? ''
      ..size = piece?.size ?? ''
      ..lot = piece?.lot ?? ''
      ..anvisa = piece?.anvisa ?? ''
      ..manufacturedOn = piece?.manufacturedOn
      ..expiresOn = piece?.expiresOn
      ..withGraft = site.grafts.isNotEmpty
      ..grafts = site.grafts.isEmpty
          ? [GraftDraft()]
          : [for (final graft in site.grafts) GraftDraft.fromMaterial(graft)];
  }

  void clearCatalogFields() {
    model = '';
    reference = '';
    size = '';
    anvisa = '';
  }

  void applyCatalogEntry(ImplantCatalogEntry entry) {
    model = entry.model;
    reference = entry.reference;
    size = entry.size;
    anvisa = entry.anvisa;
  }

  ImplantCatalogLookup selectModelOrReference(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      clearCatalogFields();
      return ImplantCatalogLookup.cleared;
    }
    final byReference = lookupImplantReference(manufacturer, trimmed);
    if (byReference != null) {
      applyCatalogEntry(byReference);
      return ImplantCatalogLookup.filled;
    }
    final modelName = catalogModelName(manufacturer, trimmed);
    if (modelName != null) {
      model = modelName;
      reference = '';
      size = '';
      anvisa = '';
      return ImplantCatalogLookup.modelOnly;
    }
    return ImplantCatalogLookup.notFound;
  }
}

class ExtraReturnDraft {
  ExtraReturnDraft({
    required this.id,
    required this.reason,
    required this.date,
    required this.reminderEnabled,
    required this.reminderDaysBefore,
  });

  final int id;
  final ReturnReason reason;
  DateTime date;
  bool reminderEnabled;
  int reminderDaysBefore;
}

class NewProcedureViewModel extends ChangeNotifier {
  NewProcedureViewModel(this.repository, {required this.patientId}) {
    final profile = repository.current.profile;
    longReminder = profile.reminderEnabled;
    longLead = profile.reminderDaysBefore;
  }

  final ClinicRepository repository;
  final String patientId;

  int step = 0;
  Modality? modality;
  ProcedureSubtype? subtype;
  bool associatedGraft = false;
  bool sinusLift = false;
  SinusLiftTechnique? sinusLiftTechnique;
  String sinusLiftNote = '';
  final Set<String> linkedImplantIds = {};
  Arch arch = Arch.superior;
  final Set<int> selected = {};
  final Map<int, ToothRole> roles = {};
  final Map<int, PieceDraft> drafts = {};
  DateTime surgery = dateOnly(DateTime.now());
  late DateTime suture = surgery.add(const Duration(days: 7));
  late DateTime longReturn = surgery.add(const Duration(days: 90));
  late bool longReminder;
  late int longLead;
  final List<ExtraReturnDraft> extraReturns = [];
  int _extraSeq = 0;
  bool catalogRefreshing = false;

  List<int> get ordered => selected.toList()..sort(compareTeeth);

  List<int> get pillars => ordered.where((tooth) {
        if (subtype != ProcedureSubtype.ponte) return true;
        return (roles[tooth] ?? ToothRole.pilar) == ToothRole.pilar;
      }).toList();

  bool get isProsthesis => modality == Modality.protese;

  bool get isImplant => modality == Modality.implante;

  bool get schedulesSurgicalReturns => modality != null && !isProsthesis;

  bool get hasDraftProgress =>
      selected.isNotEmpty || linkedImplantIds.isNotEmpty || associatedGraft || extraReturns.isNotEmpty;

  String get draftLabel => classificationLabelFor(
        modality: modality ?? Modality.implante,
        subtype: subtype,
        associatedGraft: associatedGraft,
      );

  List<InstalledImplant> get linkableImplants =>
      repository.current.implantsFor(patientId, activeOnly: true);

  bool get canContinue => switch (subtype) {
        ProcedureSubtype.ponte => selected.isNotEmpty && isContiguousSpan(selected) && pillars.isNotEmpty,
        ProcedureSubtype.protocolo => selected.length >= 2,
        ProcedureSubtype.unitario || null => modality != null && selected.isNotEmpty,
      };

  Arch? get disabledArch => subtype == ProcedureSubtype.protocolo
      ? (arch == Arch.superior ? Arch.inferior : Arch.superior)
      : null;

  bool get asksSinusLift => modality == Modality.enxerto || associatedGraft;

  String? get saveError => sinusLiftIssue(
        applies: asksSinusLift,
        sinusLift: sinusLift,
        technique: sinusLiftTechnique,
        note: sinusLiftNote,
      );

  List<InstalledImplant> linkedImplantsForTooth(int tooth) {
    return [
      for (final implant in linkableImplants)
        if (linkedImplantIds.contains(implant.id) && implant.fdi == tooth) implant,
    ];
  }

  InstalledImplant addPreexistingImplant({
    required int fdi,
    String manufacturer = '',
    String model = '',
    String size = '',
    String lot = '',
    DateTime? installedOn,
    String originClinic = '',
    String notes = '',
    bool link = true,
  }) {
    final implant = repository.createInstalledImplant(
      InstalledImplant(
        id: repository.allocateId('imp'),
        patientId: patientId,
        fdi: fdi,
        origin: ImplantOrigin.preexisting,
        manufacturer: manufacturer,
        model: model,
        size: size,
        lot: lot,
        installedOn: installedOn,
        originClinic: originClinic,
        notes: notes,
      ),
    );
    if (link) linkedImplantIds.add(implant.id);
    notifyListeners();
    return implant;
  }

  bool get associatedGraftHasData =>
      sinusLift ||
      sinusLiftNote.isNotEmpty ||
      drafts.values.any(
        (draft) => draft.grafts.any(
          (graft) =>
              graft.materialChoice != null ||
              graft.manufacturer.isNotEmpty ||
              graft.model.isNotEmpty ||
              graft.size.isNotEmpty ||
              graft.donorSite.isNotEmpty ||
              graft.lot.isNotEmpty ||
              graft.presentation != null,
        ),
      );

  void chooseModality(Modality value, {ProcedureSubtype? subtype}) {
    modality = value;
    this.subtype = value == Modality.enxerto ? null : subtype ?? ProcedureSubtype.unitario;
    _clearClinicalDraft();
    step = 1;
    notifyListeners();
  }

  void selectMain(Modality value) {
    if (modality != value) _clearClinicalDraft();
    modality = value;
    subtype = null;
    step = value == Modality.enxerto ? 1 : 0;
    notifyListeners();
  }

  void selectSubtype(ProcedureSubtype value) {
    if (subtype != value) _clearClinicalDraft();
    subtype = value;
    step = 1;
    notifyListeners();
  }

  void setAssociatedGraft(bool value, {bool discard = false}) {
    if (!value && associatedGraftHasData && !discard) return;
    associatedGraft = value;
    if (!value) _clearSinusLift();
    for (final draft in drafts.values) {
      draft.withGraft = value;
      if (!value) draft.grafts = [GraftDraft()];
    }
    if (schedulesSurgicalReturns) {
      longReturn = addCalendarMonths(surgery, longMonths);
    }
    notifyListeners();
  }

  void toggleLinkedImplant(String id) {
    if (!linkedImplantIds.add(id)) linkedImplantIds.remove(id);
    notifyListeners();
  }

  void _clearClinicalDraft() {
    selected.clear();
    roles.clear();
    drafts.clear();
    linkedImplantIds.clear();
    associatedGraft = false;
    _clearSinusLift();
    extraReturns.clear();
  }

  void setSinusLift(bool value) {
    sinusLift = value;
    if (!value) {
      sinusLiftTechnique = null;
      sinusLiftNote = '';
    }
    notifyListeners();
  }

  void setSinusLiftTechnique(SinusLiftTechnique value) {
    sinusLiftTechnique = value;
    if (value != SinusLiftTechnique.outro) sinusLiftNote = '';
    notifyListeners();
  }

  void setSinusLiftNote(String value) {
    sinusLiftNote = value;
    notifyListeners();
  }

  void _clearSinusLift() {
    sinusLift = false;
    sinusLiftTechnique = null;
    sinusLiftNote = '';
  }

  void chooseArch(Arch value) {
    arch = value;
    selected.clear();
    roles.clear();
    notifyListeners();
  }

  void backToModality() {
    step = 0;
    notifyListeners();
  }

  void backToMouth() {
    step = 1;
    notifyListeners();
  }

  String? toggleTooth(int tooth) {
    final current = modality;
    if (current == null) return null;
    if (selected.contains(tooth)) {
      selected.remove(tooth);
      roles.remove(tooth);
      drafts.remove(tooth);
      _syncRoles();
      notifyListeners();
      return null;
    }
    if (subtype == ProcedureSubtype.ponte) {
      final next = {...selected, tooth};
      if (!isContiguousSpan(next)) {
        return 'A ponte precisa de um trecho contínuo da mesma arcada.';
      }
    }
    if (subtype == ProcedureSubtype.protocolo && sideOf(tooth) != arch) return null;
    selected.add(tooth);
    _syncRoles();
    notifyListeners();
    return null;
  }

  void flipRole(int tooth) {
    final current = roles[tooth] ?? ToothRole.pilar;
    roles[tooth] = current == ToothRole.pilar ? ToothRole.pontico : ToothRole.pilar;
    notifyListeners();
  }

  Future<void> openSummary() async {
    if (catalogRefreshing) return;
    catalogRefreshing = true;
    notifyListeners();
    try {
      // Lista de fabricantes/modelos/tamanhos (e enxertos) atualizada antes do resumo.
      await repository.refreshCatalog();
    } finally {
      catalogRefreshing = false;
    }
    for (final tooth in pillars) {
      drafts.putIfAbsent(tooth, PieceDraft.new);
    }
    drafts.removeWhere((tooth, _) => !pillars.contains(tooth));
    longReturn = addCalendarMonths(surgery, longMonths);
    step = 2;
    notifyListeners();
  }

  int get longMonths {
    if (modality == Modality.enxerto || associatedGraft) return 6;
    return 3;
  }

  ReturnReason get longReason => switch (modality!) {
        Modality.enxerto => ReturnReason.instalarImplante,
        Modality.implante when subtype == ProcedureSubtype.protocolo => ReturnReason.instalarProtocolo,
        Modality.implante => ReturnReason.osseointegracao,
        Modality.protese => ReturnReason.controle,
      };

  void setSurgery(DateTime value) {
    surgery = value;
    suture = value.add(const Duration(days: 7));
    longReturn = addCalendarMonths(value, longMonths);
    notifyListeners();
  }

  void setSuture(DateTime value) {
    suture = value;
    notifyListeners();
  }

  void setLongReturn(DateTime value) {
    longReturn = value;
    notifyListeners();
  }

  void setLongReminder(bool value) {
    longReminder = value;
    notifyListeners();
  }

  void setLongLead(int value) {
    longLead = normalizeReminderDaysBefore(value);
    notifyListeners();
  }

  void addExtraReturn(ReturnReason reason) {
    extraReturns.add(
      ExtraReturnDraft(
        id: _extraSeq++,
        reason: reason,
        date: _freeReturnDate(_seedFor(reason)),
        reminderEnabled: longReminder,
        reminderDaysBefore: longLead,
      ),
    );
    _sortExtraReturns();
    notifyListeners();
  }

  void setExtraDate(int id, DateTime value) {
    final draft = _extraById(id);
    if (draft == null) return;
    draft.date = dateOnly(value);
    _sortExtraReturns();
    notifyListeners();
  }

  void setExtraReminder(int id, bool value) {
    final draft = _extraById(id);
    if (draft == null) return;
    draft.reminderEnabled = value;
    notifyListeners();
  }

  void setExtraLead(int id, int value) {
    final draft = _extraById(id);
    if (draft == null) return;
    draft.reminderDaysBefore = normalizeReminderDaysBefore(value);
    notifyListeners();
  }

  void removeExtraReturn(int id) {
    extraReturns.removeWhere((item) => item.id == id);
    notifyListeners();
  }

  ExtraReturnDraft? _extraById(int id) {
    for (final draft in extraReturns) {
      if (draft.id == id) return draft;
    }
    return null;
  }

  DateTime _seedFor(ReturnReason reason) {
    if (reason == ReturnReason.reabertura) return addCalendarMonths(longReturn, 1);
    return surgery.add(const Duration(days: 30));
  }

  DateTime _freeReturnDate(DateTime seed) {
    var date = dateOnly(seed);
    final taken = {
      dateOnly(suture),
      dateOnly(longReturn),
      for (final extra in extraReturns) dateOnly(extra.date),
    };
    while (taken.contains(date)) {
      date = date.add(const Duration(days: 1));
    }
    return date;
  }

  void _sortExtraReturns() {
    extraReturns.sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      if (byDate != 0) return byDate;
      return returnReasonOrder(a.reason).compareTo(returnReasonOrder(b.reason));
    });
  }

  void copyFromFirst() {
    final first = drafts[pillars.first];
    if (first == null) return;
    for (final tooth in pillars.skip(1)) {
      final draft = drafts[tooth];
      if (draft == null) continue;
      draft.manufacturer = first.manufacturer;
      draft.model = first.model;
      draft.reference = first.reference;
      draft.size = first.size;
      draft.anvisa = first.anvisa;
      draft.withGraft = first.withGraft;
      draft.grafts = [for (final graft in first.grafts) graft.copy()];
    }
    notifyListeners();
  }

  void updateDraft(int tooth, void Function(PieceDraft draft) change) {
    final draft = drafts[tooth];
    if (draft == null) return;
    change(draft);
    if (draft.withGraft) {
      longReturn = addCalendarMonths(surgery, longMonths);
    }
    notifyListeners();
  }

  void addGraft(int tooth) {
    updateDraft(tooth, (draft) => draft.grafts.add(GraftDraft()));
  }

  void removeGraft(int tooth, int index) {
    updateDraft(tooth, (draft) {
      if (draft.grafts.length <= 1) return;
      draft.grafts.removeAt(index);
    });
  }

  List<Procedure> save() {
    final current = modality!;
    final recordSinus = current == Modality.enxerto || (isImplant && associatedGraft);
    final teeth = ordered;
    final created = [
      Procedure(
        id: repository.allocateId('pro'),
        patientId: patientId,
        modality: current,
        subtype: subtype,
        associatedGraft: isImplant && associatedGraft,
        sinusLift: recordSinus && sinusLift,
        sinusLiftTechnique: recordSinus && sinusLift ? sinusLiftTechnique : null,
        sinusLiftNote: recordSinus && sinusLift ? sinusLiftNote.trim() : '',
        linkedImplantIds: isProsthesis ? linkedImplantIds.toList() : const [],
        linkedProcedureIds: const [],
        arch: subtype == ProcedureSubtype.protocolo ? arch : null,
        surgeryDate: surgery,
        statusLabel: switch (current) {
          Modality.enxerto => graftStatusLabel(GraftStatus.realizado),
          Modality.protese => implantStatusLabel(ImplantStatus.protese),
          Modality.implante => implantStatusLabel(ImplantStatus.instalado),
        },
        sites: [
          for (final tooth in teeth)
            ToothSite(
              fdi: tooth,
              role: roles[tooth] ?? ToothRole.pilar,
              piece: current != Modality.implante || roles[tooth] == ToothRole.pontico
                  ? null
                  : ImplantPiece(
                      manufacturer: drafts[tooth]?.manufacturer ?? '',
                      model: drafts[tooth]?.model ?? '',
                      reference: drafts[tooth]?.reference ?? '',
                      size: drafts[tooth]?.size ?? '',
                      lot: drafts[tooth]?.lot ?? '',
                      anvisa: drafts[tooth]?.anvisa ?? '',
                      manufacturedOn: drafts[tooth]?.manufacturedOn,
                      expiresOn: drafts[tooth]?.expiresOn,
                    ),
              grafts: _graftsFor(tooth),
            ),
        ],
        followUps: chronologicalFollowUps([
          if (schedulesSurgicalReturns)
            FollowUp(
              id: repository.allocateId('ret'),
              date: suture,
              reason: ReturnReason.sutura,
              status: ReturnStatus.agendado,
              reminderEnabled: false,
            ),
          for (final extra in extraReturns)
            FollowUp(
              id: repository.allocateId('ret'),
              date: extra.date,
              reason: extra.reason,
              status: ReturnStatus.agendado,
              reminderEnabled: extra.reminderEnabled,
              reminderDaysBefore: extra.reminderDaysBefore,
            ),
          if (schedulesSurgicalReturns)
            FollowUp(
              id: repository.allocateId('ret'),
              date: longReturn,
              reason: longReason,
              status: ReturnStatus.agendado,
              reminderEnabled: longReminder,
              reminderDaysBefore: longLead,
            ),
        ]),
      ),
    ];
    repository.saveProcedures(created);
    return created;
  }

  List<GraftMaterial> _graftsFor(int tooth) {
    final draft = drafts[tooth];
    if (draft == null) return const [];
    final include = modality == Modality.enxerto || (isImplant && associatedGraft && draft.withGraft);
    if (!include || roles[tooth] == ToothRole.pontico) return const [];
    return [for (final graft in draft.grafts) graft.toMaterial()];
  }

  void _syncRoles() {
    if (subtype != ProcedureSubtype.ponte) {
      for (final tooth in selected) {
        roles[tooth] = ToothRole.pilar;
      }
      return;
    }
    final teeth = ordered;
    roles.removeWhere((tooth, _) => !selected.contains(tooth));
    for (var index = 0; index < teeth.length; index++) {
      final tooth = teeth[index];
      final isEnd = index == 0 || index == teeth.length - 1;
      roles.putIfAbsent(tooth, () => teeth.length <= 2 || isEnd ? ToothRole.pilar : ToothRole.pontico);
    }
  }
}
