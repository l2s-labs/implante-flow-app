import 'package:implate_flow/domain/clinic_snapshot.dart';
import 'package:implate_flow/domain/models.dart';

/// Dados de demonstração usados apenas pela suíte de testes.
class MockClinicService {
  ClinicSnapshot load() => buildDemoSnapshot();
}

ClinicSnapshot buildDemoSnapshot() {
  var sequence = 0;
  String nextId(String prefix) {
    sequence += 1;
    return '$prefix-$sequence';
  }
  final patients = <Patient>[];
  final procedures = <Procedure>[];
    final today = brasiliaToday();
    DateTime shift(int days) => today.add(Duration(days: days));

    const centro = 'loc-centro';
    final maria = Patient(
      id: nextId('pac'),
      name: 'Maria Souza',
      phone: '11988881001',
      email: 'maria@exemplo.com',
      cpf: '39053344705',
      birthDate: DateTime(1978, 4, 12),
      locationIds: [centro],
      notifyByEmail: true,
    );
    final joao = Patient(
      id: nextId('pac'),
      name: 'João Lima',
      phone: '11977772002',
      cpf: '52998224725',
      birthDate: DateTime(1965, 9, 3),
    );
    final ana = Patient(
      id: nextId('pac'),
      name: 'Ana Costa',
      phone: '21966663003',
      cpf: '15350946056',
      birthDate: DateTime(1984, 1, 28),
    );
    final pedro = Patient(
      id: nextId('pac'),
      name: 'Pedro Alves',
      phone: '31955554004',
      cpf: '11144477735',
      birthDate: DateTime(2014, 7, 19),
      guardian: 'Lucia Alves',
    );
    patients.addAll([maria, joao, ana, pedro]);

    procedures.add(
      Procedure(
        id: nextId('pro'),
        patientId: maria.id,
        modality: Modality.implante,
        subtype: ProcedureSubtype.unitario,
        surgeryDate: shift(-40),
        statusLabel: implantStatusLabel(ImplantStatus.osseointegracao),
        sites: [
          ToothSite(
            fdi: 36,
            role: ToothRole.pilar,
            piece: ImplantPiece(
              manufacturer: 'Neodent',
              model: 'Drive GM',
              size: '3.5 × 11.5 mm',
              lot: 'L24-118',
              manufacturedOn: DateTime(2024, 11, 2),
              expiresOn: DateTime(2029, 11, 2),
              anvisa: '80123450001',
            ),
          ),
        ],
        visits: [
          Visit(
            id: nextId('con'),
            date: shift(-33),
            note: 'Sutura removida, sem intercorrência',
            statusLabel: implantStatusLabel(ImplantStatus.osseointegracao),
          ),
        ],
        followUps: [
          FollowUp(
            id: nextId('ret'),
            date: shift(-33),
            reason: ReturnReason.sutura,
            status: ReturnStatus.realizado,
            reminderEnabled: false,
            reminderDaysBefore: defaultReminderDaysBefore,
          ),
          FollowUp(
            id: nextId('ret'),
            date: shift(-1),
            reason: ReturnReason.osseointegracao,
            status: ReturnStatus.agendado,
            reminderEnabled: true,
            reminderDaysBefore: defaultReminderDaysBefore,
          ),
        ],
        photos: [
          ClinicPhoto(id: nextId('fot'), caption: 'Oclusal pós-operatória, dente 36'),
        ],
      ),
    );

    final joaoImplantId = nextId('pro');
    final joaoImp14 = nextId('imp');
    final joaoImp16 = nextId('imp');
    final implants = <InstalledImplant>[
      InstalledImplant(
        id: joaoImp14,
        patientId: joao.id,
        fdi: 14,
        origin: ImplantOrigin.procedureRecorded,
        sourceProcedureId: joaoImplantId,
        manufacturer: 'Straumann',
        model: 'BLX',
        size: '3.75 × 10 mm',
        lot: 'B25-014',
        installedOn: shift(-12),
      ),
      InstalledImplant(
        id: joaoImp16,
        patientId: joao.id,
        fdi: 16,
        origin: ImplantOrigin.procedureRecorded,
        sourceProcedureId: joaoImplantId,
        manufacturer: 'Straumann',
        model: 'BLX',
        size: '4.0 × 10 mm',
        lot: 'B25-016',
        installedOn: shift(-12),
      ),
    ];
    procedures.add(
      Procedure(
        id: joaoImplantId,
        patientId: joao.id,
        modality: Modality.implante,
        subtype: ProcedureSubtype.unitario,
        surgeryDate: shift(-12),
        statusLabel: implantStatusLabel(ImplantStatus.instalado),
        sites: [
          ToothSite(
            fdi: 14,
            role: ToothRole.pilar,
            piece: ImplantPiece(
              manufacturer: 'Straumann',
              model: 'BLX',
              size: '3.75 × 10 mm',
              lot: 'B25-014',
              manufacturedOn: DateTime(2025, 2, 1),
              expiresOn: DateTime(2030, 2, 1),
            ),
          ),
          ToothSite(
            fdi: 16,
            role: ToothRole.pilar,
            piece: ImplantPiece(
              manufacturer: 'Straumann',
              model: 'BLX',
              size: '4.0 × 10 mm',
              lot: 'B25-016',
              manufacturedOn: DateTime(2025, 2, 1),
              expiresOn: DateTime(2030, 2, 1),
            ),
          ),
        ],
        followUps: [
          FollowUp(
            id: nextId('ret'),
            date: today,
            reason: ReturnReason.sutura,
            status: ReturnStatus.agendado,
            reminderEnabled: false,
            reminderDaysBefore: defaultReminderDaysBefore,
          ),
          FollowUp(
            id: nextId('ret'),
            date: shift(78),
            reason: ReturnReason.osseointegracao,
            status: ReturnStatus.agendado,
            reminderEnabled: true,
            reminderDaysBefore: 30,
          ),
        ],
      ),
    );
    procedures.add(
      Procedure(
        id: nextId('pro'),
        patientId: joao.id,
        modality: Modality.protese,
        subtype: ProcedureSubtype.ponte,
        linkedImplantIds: [joaoImp14, joaoImp16],
        linkedProcedureIds: [joaoImplantId],
        surgeryDate: shift(78),
        statusLabel: implantStatusLabel(ImplantStatus.protese),
        sites: const [
          ToothSite(fdi: 14, role: ToothRole.pilar),
          ToothSite(fdi: 15, role: ToothRole.pontico),
          ToothSite(fdi: 16, role: ToothRole.pilar),
        ],
        followUps: [
          FollowUp(
            id: nextId('ret'),
            date: shift(90),
            reason: ReturnReason.controle,
            status: ReturnStatus.agendado,
            reminderEnabled: true,
            reminderDaysBefore: defaultReminderDaysBefore,
          ),
        ],
      ),
    );

    procedures.add(
      Procedure(
        id: nextId('pro'),
        patientId: ana.id,
        modality: Modality.implante,
        subtype: ProcedureSubtype.protocolo,
        associatedGraft: true,
        arch: Arch.superior,
        surgeryDate: shift(-2),
        statusLabel: implantStatusLabel(ImplantStatus.instalado),
        notes: 'Pilar 16 com enxerto no mesmo ato',
        sites: [
          for (final tooth in [16, 14, 24, 26])
            ToothSite(
              fdi: tooth,
              role: ToothRole.pilar,
              piece: ImplantPiece(
                manufacturer: 'Nobel Biocare',
                model: 'NobelActive',
                size: tooth == 16 ? '4.3 × 13 mm' : '3.5 × 13 mm',
              ),
              grafts: tooth == 16
                  ? [
                      GraftMaterial(
                        origin: GraftOrigin.biomaterial,
                        manufacturer: 'Geistlich',
                        model: 'Bio-Oss',
                        size: '0.5 g',
                        lot: 'GO-5521',
                        expiresOn: DateTime(2028, 6, 1),
                      ),
                    ]
                  : [],
            ),
        ],
        followUps: [
          FollowUp(
            id: nextId('ret'),
            date: today,
            reason: ReturnReason.sutura,
            status: ReturnStatus.agendado,
            reminderEnabled: false,
            reminderDaysBefore: defaultReminderDaysBefore,
          ),
          FollowUp(
            id: nextId('ret'),
            date: shift(180),
            reason: ReturnReason.instalarProtocolo,
            status: ReturnStatus.agendado,
            reminderEnabled: false,
            reminderDaysBefore: defaultReminderDaysBefore,
          ),
        ],
        photos: [
          ClinicPhoto(id: nextId('fot'), caption: 'Arcada superior, protocolo'),
        ],
      ),
    );

    procedures.add(
      Procedure(
        id: nextId('pro'),
        patientId: pedro.id,
        modality: Modality.enxerto,
        surgeryDate: shift(-20),
        statusLabel: graftStatusLabel(GraftStatus.maturacao),
        sites: [
          ToothSite(
            fdi: 46,
            role: ToothRole.pilar,
            grafts: [
              GraftMaterial(
                origin: GraftOrigin.autogeno,
                donorSite: 'Ramo mandibular direito',
              ),
            ],
          ),
        ],
        followUps: [
          FollowUp(
            id: nextId('ret'),
            date: today,
            reason: ReturnReason.sutura,
            status: ReturnStatus.agendado,
            reminderEnabled: false,
            reminderDaysBefore: defaultReminderDaysBefore,
          ),
          FollowUp(
            id: nextId('ret'),
            date: shift(160),
            reason: ReturnReason.instalarImplante,
            status: ReturnStatus.agendado,
            reminderEnabled: true,
            reminderDaysBefore: defaultReminderDaysBefore,
          ),
        ],
      ),
    );
  return ClinicSnapshot(
    profile: DentistProfile(
      name: 'Dra. Helena Vargas',
      email: 'helena@consultorio.exemplo',
      phone: '1133334040',
      cro: 'SP 00000',
      locations: [
        CareLocation(
          id: centro,
          name: 'Consultório Centro',
          address: 'Rua das Flores, 100',
          isDefault: true,
        ),
      ],
    ),
    signedIn: false,
    patients: patients,
    procedures: procedures,
    implants: implants,
    sequence: sequence,
  );
}
