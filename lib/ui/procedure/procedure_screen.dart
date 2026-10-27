import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../data/services/clinic_files.dart';
import '../../domain/models.dart';
import '../../domain/practice.dart';
import '../core/app_sheet.dart';
import '../core/date_picker.dart';
import '../core/layout.dart';
import '../view_models.dart';
import 'traceability_editor.dart';

class ProcedureScreen extends StatelessWidget {
  const ProcedureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ProcedureViewModel>();
    final procedure = viewModel.procedure;
    final patient = viewModel.patient;
    if (procedure == null || patient == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Procedimento')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Procedimento não encontrado.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              TextButton(onPressed: () => context.pop(), child: const Text('Voltar')),
            ],
          ),
        ),
      );
    }
    final events = <({DateTime date, String title, String detail})>[
      (date: procedure.surgeryDate, title: 'Cirurgia', detail: procedure.classificationLabel),
      for (final visit in procedure.visits) (date: visit.date, title: 'Consulta', detail: visit.note),
      for (final followUp in procedure.followUps)
        if (!followUp.isProsthesisTrack)
          (
            date: followUp.date,
            title: returnStatusLabel(followUp.status),
            detail: returnReasonLabel(followUp.reason),
          )
        else
          (
            date: followUp.date,
            title: followUpPhaseLabel(followUp.phase!),
            detail: followUp.phase == FollowUpPhase.definitive && followUp.prosthesisStatus != null
                ? prosthesisFollowUpStatusLabel(followUp.prosthesisStatus!)
                : 'Sem status',
          ),
    ]..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      appBar: AppBar(
        title: Text(procedure.classificationLabel),
        actions: [
          IconButton(
            tooltip: 'Excluir procedimento',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDeleteProcedure(context, viewModel, procedure),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          AppSurfaceCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patient.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text('${formatDay(procedure.surgeryDate)} · ${procedure.teethLabel}'),
                if (procedure.sinusLiftLabel != null) Text(procedure.sinusLiftLabel!),
                Text(procedure.statusLabel),
                if (procedure.notes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(procedure.notes),
                ],
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => _editNotes(context, viewModel),
                    child: const Text('Editar notas'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          AppSectionHeader(
            title: 'Rastreio',
            action: TextButton(
              onPressed: () async {
                final sites = await editTraceability(context, procedure: procedure);
                if (sites != null) {
                  viewModel.saveTraceability(
                    sites: sites.sites,
                    sinusLift: sites.sinusLift,
                    sinusLiftTechnique: sites.sinusLiftTechnique,
                    sinusLiftNote: sites.sinusLiftNote,
                  );
                }
              },
              child: const Text('Editar'),
            ),
          ),
          const SizedBox(height: 8),
          for (final site in procedure.sites) ...[
            AppSurfaceCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dente ${site.fdi} · ${roleLabel(site.role)}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  if (site.piece != null)
                    Text(
                      '${site.piece!.manufacturer} ${site.piece!.model} ${site.piece!.size}',
                    ),
                  for (final graft in site.grafts) Text(graftTraceLabel(graft)),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 12),
          const AppSectionHeader(
            title: 'Avisos ao paciente',
            subtitle: 'Só uma mudança de etapa confirmada pode gerar aviso. A entrega depende do serviço.',
          ),
          const SizedBox(height: 8),
          if (procedure.stageNotices.isEmpty)
            const AppEmptyHint('Nenhum aviso de etapa.')
          else
            for (final notice in procedure.stageNotices) ...[
              AppSurfaceCard(
                child: ListTile(
                  title: Text(notice.stageLabel),
                  subtitle: Text(stageNoticeStatusLabel(notice)),
                  trailing: notice.delivery == NoticeDelivery.falha
                      ? TextButton(
                          onPressed: () => viewModel.reprocessNotice(notice.id),
                          child: const Text('Tentar novamente'),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 8),
            ],
          const SizedBox(height: 12),
          const AppSectionHeader(title: 'Linha do tempo'),
          const SizedBox(height: 8),
          for (final event in events) ...[
            AppSurfaceCard(
              child: ListTile(
                title: Text(event.title),
                subtitle: Text('${formatDay(event.date)} · ${event.detail}'),
              ),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 12),
          const AppSectionHeader(title: 'Fotos'),
          const SizedBox(height: 8),
          if (procedure.photos.isEmpty) const AppEmptyHint('Nenhuma foto.'),
          for (final photo in procedure.photos) ...[
            AppSurfaceCard(
              child: ListTile(
                leading: photo.path.isEmpty
                    ? const Icon(Icons.image_outlined)
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(photo.path),
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) =>
                              const Icon(Icons.broken_image_outlined),
                        ),
                      ),
                title: Text(photo.caption),
                subtitle: Text(photo.path.isEmpty ? 'Legenda sem arquivo' : 'Arquivo local'),
              ),
            ),
            const SizedBox(height: 8),
          ],
          OutlinedButton.icon(
            onPressed: () => _addPhoto(context, viewModel),
            icon: const Icon(Icons.add_a_photo_outlined),
            label: const Text('Adicionar foto'),
          ),
          const SizedBox(height: 20),
          const AppSectionHeader(title: 'Ações'),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () => context.push('/procedures/${procedure.id}/certificate'),
            child: const Text('Emitir certificado'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => _visit(context, viewModel, procedure),
            child: const Text('Registrar consulta'),
          ),
          for (final followUp in procedure.followUps)
            if (!followUp.isProsthesisTrack && followUp.status == ReturnStatus.agendado) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => _complete(context, viewModel, procedure, followUp.id),
                child: Text('Registrar ${returnReasonLabel(followUp.reason)}'),
              ),
            ],
          if (procedure.modality == Modality.protese) ...[
            const SizedBox(height: 20),
            AppSectionHeader(
              title: 'Follow-up de prótese',
              action: PopupMenuButton<FollowUpPhase>(
                tooltip: 'Adicionar',
                onSelected: (phase) => viewModel.addProsthesisFollowUp(phase: phase),
                itemBuilder: (context) => const [
                  PopupMenuItem(value: FollowUpPhase.provisional, child: Text('Provisório')),
                  PopupMenuItem(value: FollowUpPhase.definitive, child: Text('Definitivo')),
                ],
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text('Adicionar'),
                ),
              ),
            ),
            const SizedBox(height: 8),
            for (final followUp in procedure.followUps)
              if (followUp.isProsthesisTrack) ...[
                AppSurfaceCard(
                  child: ListTile(
                    title: Text(followUpPhaseLabel(followUp.phase!)),
                    subtitle: Text(
                      followUp.phase == FollowUpPhase.provisional
                          ? 'Sem cadeia de status'
                          : followUp.prosthesisStatus == null
                              ? 'Definitivo'
                              : prosthesisFollowUpStatusLabel(followUp.prosthesisStatus!),
                    ),
                    trailing: followUp.phase == FollowUpPhase.definitive
                        ? TextButton(
                            onPressed: () => _editProsthesisFollowUp(context, viewModel, followUp),
                            child: const Text('Atualizar'),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 8),
              ],
          ],
        ],
      ),
    );
  }

  Future<void> _editProsthesisFollowUp(
    BuildContext context,
    ProcedureViewModel viewModel,
    FollowUp followUp,
  ) async {
    final result = await showAppSheet<({ProsthesisFollowUpStatus status, DateTime? date})>(
      context: context,
      builder: (context) => _ProsthesisStatusSheet(followUp: followUp),
    );
    if (result == null) return;
    viewModel.updateProsthesisFollowUp(
      followUpId: followUp.id,
      status: result.status,
      statusDate: result.date,
    );
  }


  Future<void> _confirmDeleteProcedure(
    BuildContext context,
    ProcedureViewModel viewModel,
    Procedure procedure,
  ) async {
    final label = procedure.classificationLabel;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir procedimento'),
        content: Text(
          'Excluir "$label"?\n\n'
          'O procedimento some da lista do paciente. Esta ação não pode ser desfeita neste app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!context.mounted) return;
    try {
      await viewModel.deleteProcedure();
      if (!context.mounted) return;
      context.pop();
    } catch (_) {
      // Erro já vai para ApiFeedbackHost; permanece na tela.
    }
  }

  Future<void> _editNotes(BuildContext context, ProcedureViewModel viewModel) async {
    final procedure = viewModel.procedure;
    if (procedure == null) return;
    final notes = await showAppSheet<String>(
      context: context,
      builder: (context) => _TextSheet(
        title: 'Notas do procedimento',
        label: 'Observação',
        initial: procedure.notes,
        maxLines: 5,
      ),
    );
    if (notes != null) viewModel.saveNotes(notes);
  }

  Future<void> _addPhoto(BuildContext context, ProcedureViewModel viewModel) async {
    final source = await showAppSheet<ImageSource>(
      context: context,
      builder: (context) => AppSheet(
        title: 'Adicionar foto',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Câmera'),
              onTap: () => AppSheet.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galeria'),
              onTap: () => AppSheet.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picked = await ImagePicker().pickImage(source: source);
    if (picked == null || !context.mounted) return;
    final caption = await showAppSheet<String>(
      context: context,
      builder: (context) => const _TextSheet(title: 'Legenda da foto', label: 'Legenda'),
    );
    if (caption == null) return;
    final id = viewModel.repository.allocateId('fot');
    final extension = picked.name.contains('.') ? picked.name.split('.').last : 'jpg';
    final path = await ClinicFiles().copyFile(picked.path, '$id.$extension');
    viewModel.addPhoto(
      ClinicPhoto(
        id: id,
        caption: caption.trim().isEmpty ? 'Foto' : caption.trim(),
        path: path,
      ),
    );
  }

  Future<void> _visit(
    BuildContext context,
    ProcedureViewModel viewModel,
    Procedure procedure,
  ) async {
    final patient = viewModel.patient;
    if (patient == null) return;
    final result = await _consultationDialog(
      context,
      procedure,
      patient: patient,
      title: 'Registrar consulta',
    );
    if (result == null) return;
    viewModel.addVisit(note: result.note, statusLabel: result.statusLabel);
  }

  Future<void> _complete(
    BuildContext context,
    ProcedureViewModel viewModel,
    Procedure procedure,
    String followUpId,
  ) async {
    final patient = viewModel.patient;
    if (patient == null) return;
    final followUp = procedure.followUps.firstWhere((item) => item.id == followUpId);
    final result = await _consultationDialog(
      context,
      procedure,
      patient: patient,
      title: 'Registrar retorno',
      withAttendance: true,
      showStatus: followUp.reason != ReturnReason.sutura,
    );
    if (result == null) return;
    viewModel.completeFollowUp(
      followUpId: followUpId,
      note: result.note,
      statusLabel: result.statusLabel,
      returnStatus: result.attendance,
    );
  }
}

class _TextSheet extends StatefulWidget {
  const _TextSheet({
    required this.title,
    required this.label,
    this.initial = '',
    this.maxLines = 1,
  });

  final String title;
  final String label;
  final String initial;
  final int maxLines;

  @override
  State<_TextSheet> createState() => _TextSheetState();
}

class _TextSheetState extends State<_TextSheet> {
  late final note = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      title: widget.title,
      dirty: note.text != widget.initial,
      footer: AppSheetActions(onSave: () => AppSheet.pop(context, note.text)),
      child: TextField(
        controller: note,
        maxLines: widget.maxLines,
        decoration: InputDecoration(labelText: widget.label),
        onChanged: (_) => setState(() {}),
      ),
    );
  }
}

class _ConsultationResult {
  const _ConsultationResult({
    required this.note,
    required this.statusLabel,
    required this.attendance,
  });

  final String note;
  final String statusLabel;
  final ReturnStatus attendance;
}

Future<_ConsultationResult?> _consultationDialog(
  BuildContext context,
  Procedure procedure, {
  required Patient patient,
  required String title,
  bool withAttendance = false,
  bool showStatus = true,
}) {
  final options = procedure.modality == Modality.enxerto
      ? [for (final status in GraftStatus.values) graftStatusLabel(status)]
      : [for (final status in ImplantStatus.values) implantStatusLabel(status)];
  final status = options.contains(procedure.statusLabel) ? procedure.statusLabel : options.first;
  return showAppSheet<_ConsultationResult>(
    context: context,
    builder: (context) => _ConsultationDialog(
      title: title,
      options: options,
      initialStatus: status,
      patient: patient,
      withAttendance: withAttendance,
      showStatus: showStatus,
    ),
  );
}

class _ConsultationDialog extends StatefulWidget {
  const _ConsultationDialog({
    required this.title,
    required this.options,
    required this.initialStatus,
    required this.patient,
    required this.withAttendance,
    required this.showStatus,
  });

  final String title;
  final List<String> options;
  final String initialStatus;
  final Patient patient;
  final bool withAttendance;
  final bool showStatus;

  @override
  State<_ConsultationDialog> createState() => _ConsultationDialogState();
}

class _ConsultationDialogState extends State<_ConsultationDialog> {
  late String status = widget.initialStatus;
  var attendance = ReturnStatus.realizado;
  final note = TextEditingController();

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  String _noticePreview() {
    final plan = stageNoticePlan(
      previousStatus: widget.initialStatus,
      nextStatus: status,
      clinicalChange: true,
      patient: widget.patient,
    );
    if (status == widget.initialStatus) {
      return 'Sem mudança de etapa, nenhum aviso é gerado.';
    }
    if (plan == null) return 'Nenhum canal habilitado para avisar o paciente.';
    return stageNoticePreview(plan);
  }

  @override
  Widget build(BuildContext context) {
    final askStatus = widget.showStatus && (!widget.withAttendance || attendance == ReturnStatus.realizado);
    return AppSheet(
      title: widget.title,
      dirty: note.text.trim().isNotEmpty ||
          attendance != ReturnStatus.realizado ||
          status != widget.initialStatus,
      footer: AppSheetActions(
        onSave: () => AppSheet.pop(
          context,
          _ConsultationResult(
            note: note.text,
            statusLabel: status,
            attendance: widget.withAttendance ? attendance : ReturnStatus.realizado,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.withAttendance)
            SegmentedButton<ReturnStatus>(
              segments: const [
                ButtonSegment(value: ReturnStatus.realizado, label: Text('Realizado')),
                ButtonSegment(value: ReturnStatus.faltou, label: Text('Faltou')),
              ],
              selected: {attendance},
              onSelectionChanged: (value) => setState(() => attendance = value.first),
            ),
          TextField(
            controller: note,
            decoration: const InputDecoration(labelText: 'Observação'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          if (askStatus) ...[
            DropdownButtonFormField<String>(
              initialValue: status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: [
                for (final option in widget.options) DropdownMenuItem(value: option, child: Text(option)),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => status = value);
              },
            ),
            const SizedBox(height: 8),
            Text(_noticePreview(), style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}


class _ProsthesisStatusSheet extends StatefulWidget {
  const _ProsthesisStatusSheet({required this.followUp});

  final FollowUp followUp;

  @override
  State<_ProsthesisStatusSheet> createState() => _ProsthesisStatusSheetState();
}

class _ProsthesisStatusSheetState extends State<_ProsthesisStatusSheet> {
  late ProsthesisFollowUpStatus status =
      widget.followUp.prosthesisStatus ?? ProsthesisFollowUpStatus.molded;
  DateTime? date;

  @override
  void initState() {
    super.initState();
    date = widget.followUp.statusDates[status.name];
  }

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      title: 'Status do definitivo',
      dirty: true,
      footer: AppSheetActions(
        onSave: () => AppSheet.pop(context, (status: status, date: date)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in prosthesisFollowUpStatusOrder)
                ChoiceChip(
                  showCheckmark: false,
                  label: Text(prosthesisFollowUpStatusLabel(option)),
                  selected: status == option,
                  onSelected: (_) => setState(() {
                    status = option;
                    date = widget.followUp.statusDates[option.name];
                  }),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Data desta etapa (opcional)'),
            subtitle: Text(date == null ? 'Não informada' : formatDay(date!)),
            trailing: TextButton(
              onPressed: () async {
                final picked = await showAppDatePicker(
                  context: context,
                  initialDate: date ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2040),
                );
                if (picked != null) setState(() => date = picked);
              },
              child: const Text('Informar'),
            ),
          ),
        ],
      ),
    );
  }
}
