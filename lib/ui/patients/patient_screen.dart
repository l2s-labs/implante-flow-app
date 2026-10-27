import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../domain/models.dart';
import '../../domain/practice.dart';
import '../core/layout.dart';
import '../view_models.dart';
import 'patient_editor.dart';
import 'preexisting_implant_sheet.dart';

class PatientScreen extends StatelessWidget {
  const PatientScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<PatientViewModel>();
    final patient = viewModel.patient;
    if (patient == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Paciente')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Paciente não encontrado.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              TextButton(onPressed: () => context.pop(), child: const Text('Voltar')),
            ],
          ),
        ),
      );
    }
    final upcoming = viewModel.upcoming;
    final implants = viewModel.implants;
    final procedures = [...viewModel.history]
      ..sort((a, b) => b.surgeryDate.compareTo(a.surgeryDate));
    return Scaffold(
      appBar: AppBar(
        title: Text(patient.name),
        actions: [
          IconButton(
            tooltip: 'Editar',
            onPressed: () => _edit(context, viewModel),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Exportar prontuário',
            onPressed: () async {
              await viewModel.exportChart();
            },
            icon: const Icon(Icons.ios_share_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'patient-new-procedure',
        onPressed: () => context.push('/patients/${patient.id}/new'),
        icon: const Icon(Icons.add),
        label: const Text('Procedimento'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          AppSurfaceCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(patient.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(patient.phone.isEmpty ? 'Sem telefone' : formatBrazilianPhone(patient.phone)),
                Text(patient.email.isEmpty ? 'Sem e-mail' : patient.email),
                Text(_locationLine(patient, viewModel.snapshot.profile.locations)),
                Text(_noticeLine(patient)),
                Text(cpfLabel(patient.cpf)),
                Text('Nascimento ${formatDay(patient.birthDate)}'),
                if (patient.isMinor && patient.guardian.isNotEmpty)
                  Text('Responsável: ${patient.guardian}'),
                if (patient.notes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(patient.notes),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          const AppSectionHeader(
            title: 'Implantes instalados',
            subtitle: 'Peças no dente (FDI). Não é o histórico de atos clínicos.',
          ),
          const SizedBox(height: 8),
          if (implants.isEmpty)
            const AppEmptyHint('Nenhum implante cadastrado.')
          else
            for (final implant in implants) ...[
              AppSurfaceCard(
                child: ListTile(
                  title: Text(implant.title),
                  subtitle: Text(implant.subtitle),
                  isThreeLine: implant.notes.isNotEmpty,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    if (implant.sourceProcedureId != null) {
                      context.push('/procedures/${implant.sourceProcedureId}');
                      return;
                    }
                    final draft = await showPreexistingImplantSheet(
                      context,
                      initial: implant,
                      allowInactive: true,
                    );
                    if (draft == null || !context.mounted) return;
                    viewModel.updateInstalledImplant(implant, draft);
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () async {
                final draft = await showPreexistingImplantSheet(context);
                if (draft == null || !context.mounted) return;
                viewModel.addPreexistingImplant(draft);
              },
              icon: const Icon(Icons.add),
              label: const Text('Adicionar implante preexistente'),
            ),
          ),
          const SizedBox(height: 12),
          const AppSectionHeader(title: 'Próximos encontros'),
          const SizedBox(height: 8),
          if (upcoming.isEmpty)
            const AppEmptyHint('Nenhum retorno agendado.')
          else
            for (final followUp in upcoming) ...[
              AppSurfaceCard(
                child: ListTile(
                  title: Text(formatDay(followUp.date)),
                  subtitle: Text(
                    followUp.reason == ReturnReason.sutura
                        ? returnReasonLabel(followUp.reason)
                        : '${returnReasonLabel(followUp.reason)} · lembrete ${followUp.reminderEnabled ? reminderLeadLabel(followUp.reminderDaysBefore) : 'desligado'}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    final procedure = viewModel.procedureOf(followUp.id);
                    if (procedure == null) return;
                    context.push('/procedures/${procedure.id}');
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          const SizedBox(height: 12),
          const AppSectionHeader(
            title: 'Procedimentos',
            subtitle: 'Atos clínicos no tempo (instalação, enxerto, prótese, reabertura…).',
          ),
          const SizedBox(height: 8),
          if (procedures.isEmpty)
            const AppEmptyHint('Nenhum procedimento cadastrado.')
          else
            for (final procedure in procedures) ...[
              AppSurfaceCard(
                child: ListTile(
                  title: Text(_procedureTitle(procedure)),
                  subtitle: Text(_procedureSubtitle(procedure)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/procedures/${procedure.id}'),
                ),
              ),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context, PatientViewModel viewModel) async {
    final patient = viewModel.patient;
    if (patient == null) return;
    final draft = await editPatientDraft(
      context,
      title: 'Editar paciente',
      locations: viewModel.snapshot.profile.locations,
      initial: PatientDraft(
        name: patient.name,
        phone: patient.phone,
        email: patient.email,
        cpf: patient.cpf,
        birthDate: patient.birthDate,
        notes: patient.notes,
        guardian: patient.guardian,
        locationIds: patient.locationIds,
        notifyByEmail: patient.notifyByEmail,
        notifyByPhone: patient.notifyByPhone,
      ),
    );
    if (draft == null) return;
    viewModel.updatePatient(
      patient.copyWith(
        name: draft.name.trim(),
        phone: draft.phone.trim(),
        email: draft.email,
        cpf: draft.cpf,
        birthDate: draft.birthDate,
        notes: draft.notes.trim(),
        guardian: draft.guardian.trim(),
        locationIds: draft.locationIds,
        notifyByEmail: draft.notifyByEmail,
        notifyByPhone: draft.notifyByPhone,
      ),
    );
  }
}

String _procedureTitle(Procedure procedure) {
  final teeth = procedure.teethLabel;
  if (teeth.isEmpty) return procedure.classificationLabel;
  return '${procedure.classificationLabel} · $teeth';
}

String _procedureSubtitle(Procedure procedure) {
  final parts = <String>[
    formatDay(procedure.surgeryDate),
    clinicalStatusDisplay(procedure.statusLabel, procedure.modality),
    if (procedure.teethLabel.isNotEmpty) procedure.teethLabel,
  ].where((part) => part.trim().isNotEmpty).toList();
  return parts.join(' · ');
}

String _locationLine(Patient patient, List<CareLocation> locations) {
  final names = [
    for (final location in locations)
      if (patient.locationIds.contains(location.id)) location.name,
  ];
  if (names.isEmpty) return 'Sem local de atendimento';
  return names.join(', ');
}

String _noticeLine(Patient patient) {
  final channels = enabledNoticeChannels(patient);
  if (channels.isEmpty) return 'Sem aviso de etapa ao paciente';
  return 'Avisa etapas por ${channels.join(' e ')}';
}
