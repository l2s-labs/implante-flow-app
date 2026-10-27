import 'package:flutter/material.dart';
import '../core/date_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../domain/models.dart';
import '../core/catalog_scope.dart';
import '../core/layout.dart';
import '../core/mouth_chart.dart';
import '../core/preset_dropdown.dart';
import '../graft/graft_form.dart';
import '../patients/preexisting_implant_sheet.dart';
import 'new_procedure_viewmodel.dart';


class NewProcedureScreen extends StatelessWidget {
  const NewProcedureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<NewProcedureViewModel>();
    final titles = ['Modalidade', 'Boca', 'Resumo'];
    return Scaffold(
      appBar: AppBar(title: Text(titles[viewModel.step])),
      body: switch (viewModel.step) {
        0 => _ModalityStep(viewModel: viewModel),
        1 => _MouthStep(viewModel: viewModel),
        _ => _SummaryStep(viewModel: viewModel),
      },
    );
  }
}

class _ModalityStep extends StatelessWidget {
  const _ModalityStep({required this.viewModel});

  final NewProcedureViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final selected = viewModel.modality;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        const AppSectionHeader(
          title: 'Modalidade',
          subtitle: 'Escolha a modalidade principal e, quando houver, o subtipo.',
        ),
        const SizedBox(height: 12),
        for (final modality in Modality.values) ...[
          AppSurfaceCard(
            child: ListTile(
              title: Text(modalityLabel(modality)),
              trailing: Icon(selected == modality ? Icons.expand_less : Icons.chevron_right),
              selected: selected == modality,
              onTap: () => _selectMain(context, modality),
            ),
          ),
          if (selected == modality && subtypesOf(modality).isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final subtype in subtypesOf(modality))
                    ChoiceChip(
                      label: Text(subtypeLabel(modality, subtype)),
                      selected: viewModel.subtype == subtype,
                      onSelected: (_) => _selectSubtype(context, subtype),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Future<void> _selectMain(BuildContext context, Modality modality) async {
    if (viewModel.modality == modality && modality != Modality.enxerto) return;
    if (viewModel.hasDraftProgress && viewModel.modality != modality) {
      final discard = await _confirmDiscard(context);
      if (!discard || !context.mounted) return;
    }
    viewModel.selectMain(modality);
  }

  Future<void> _selectSubtype(BuildContext context, ProcedureSubtype subtype) async {
    if (viewModel.subtype == subtype) {
      viewModel.selectSubtype(subtype);
      return;
    }
    if (viewModel.hasDraftProgress && viewModel.subtype != subtype) {
      final discard = await _confirmDiscard(context);
      if (!discard || !context.mounted) return;
    }
    viewModel.selectSubtype(subtype);
  }
}

Future<bool> _confirmDiscard(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Trocar a seleção'),
      content: const Text('Dentes e dados já preenchidos serão descartados.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Trocar')),
      ],
    ),
  );
  return ok == true;
}

class _MouthStep extends StatelessWidget {
  const _MouthStep({required this.viewModel});

  final NewProcedureViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              AppSectionHeader(
                title: viewModel.draftLabel,
                subtitle: 'Toque o dente para selecionar.',
              ),
              if (viewModel.subtype == ProcedureSubtype.protocolo) ...[
                const SizedBox(height: 12),
                SegmentedButton<Arch>(
                  segments: const [
                    ButtonSegment(value: Arch.superior, label: Text('Superior')),
                    ButtonSegment(value: Arch.inferior, label: Text('Inferior')),
                  ],
                  selected: {viewModel.arch},
                  onSelectionChanged: (value) => viewModel.chooseArch(value.first),
                ),
              ],
              const SizedBox(height: 12),
              AppSurfaceCard(
                padding: const EdgeInsets.all(8),
                child: MouthChart(
                  selected: viewModel.selected,
                  disabledArch: viewModel.disabledArch,
                  onToothTap: (tooth) {
                    final message = viewModel.toggleTooth(tooth);
                    if (message != null) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
                    }
                  },
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tooth in viewModel.ordered)
                    InputChip(
                      label: Text(
                        viewModel.subtype == ProcedureSubtype.ponte
                            ? '$tooth · ${roleLabel(viewModel.roles[tooth] ?? ToothRole.pilar)}'
                            : '$tooth',
                      ),
                      onPressed: viewModel.subtype == ProcedureSubtype.ponte ? () => viewModel.flipRole(tooth) : null,
                      onDeleted: () => viewModel.toggleTooth(tooth),
                    ),
                ],
              ),
              if (viewModel.selected.isEmpty) const AppEmptyHint('Nenhum dente selecionado.'),
              if (viewModel.catalogRefreshing) ...[
                const SizedBox(height: 16),
                const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ],
            ],
          ),
        ),
        AppFooterBar(
          secondaryLabel: 'Voltar',
          primaryLabel: 'Continuar',
          onSecondary: viewModel.backToModality,
          onPrimary: viewModel.openSummary,
          primaryEnabled: viewModel.canContinue && !viewModel.catalogRefreshing,
        ),
      ],
    );
  }
}

class _SummaryStep extends StatelessWidget {
  const _SummaryStep({required this.viewModel});

  final NewProcedureViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final pontics = viewModel.ordered
        .where((tooth) => viewModel.roles[tooth] == ToothRole.pontico)
        .toList();
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _OverviewCard(viewModel: viewModel),
              if (viewModel.subtype == ProcedureSubtype.ponte && pontics.isNotEmpty) ...[
                const SizedBox(height: 12),
                _PonticCard(teeth: pontics),
              ],
              const SizedBox(height: 20),
              if (viewModel.isImplant) ...[
                const AppSectionHeader(title: 'Foi realizado enxerto?'),
                const SizedBox(height: 8),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Não')),
                    ButtonSegment(value: true, label: Text('Sim')),
                  ],
                  selected: {viewModel.associatedGraft},
                  onSelectionChanged: (value) => _setAssociatedGraft(context, value.first),
                ),
                const SizedBox(height: 20),
              ],
              if (viewModel.isProsthesis) ...[
                const AppSectionHeader(
                  title: 'Implantes vinculados',
                  subtitle: 'Opcional. Pode salvar sem vínculo ou cadastrar um preexistente.',
                ),
                const SizedBox(height: 8),
                if (viewModel.linkableImplants.isEmpty)
                  const AppEmptyHint('Nenhum implante deste paciente.')
                else
                  for (final implant in viewModel.linkableImplants) ...[
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(implant.title),
                      subtitle: Text(implant.subtitle),
                      value: viewModel.linkedImplantIds.contains(implant.id),
                      onChanged: (_) => viewModel.toggleLinkedImplant(implant.id),
                    ),
                  ],
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () async {
                      final draft = await showPreexistingImplantSheet(context);
                      if (draft == null || !context.mounted) return;
                      viewModel.addPreexistingImplant(
                        fdi: draft.fdi,
                        manufacturer: draft.manufacturer,
                        model: draft.model,
                        size: draft.size,
                        lot: draft.lot,
                        installedOn: draft.installedOn,
                        originClinic: draft.originClinic,
                        notes: draft.notes,
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Adicionar implante preexistente'),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (viewModel.asksSinusLift) ...[
                const AppSectionHeader(title: 'Levantamento de seio'),
                SinusLiftFields(
                  sinusLift: viewModel.sinusLift,
                  technique: viewModel.sinusLiftTechnique,
                  note: viewModel.sinusLiftNote,
                  onLift: viewModel.setSinusLift,
                  onTechnique: viewModel.setSinusLiftTechnique,
                  onNote: viewModel.setSinusLiftNote,
                ),
                const SizedBox(height: 20),
              ],
              AppSectionHeader(
                title: viewModel.isProsthesis
                    ? (viewModel.subtype == ProcedureSubtype.protocolo
                        ? 'Rastreabilidade da região'
                        : 'Rastreabilidade da prótese')
                    : 'Rastreio',
                subtitle: viewModel.isProsthesis
                    ? 'Consulta os implantes vinculados nesta região. O vínculo é opcional.'
                    : 'Pode ficar em branco e ser completado depois.',
                action: viewModel.pillars.length > 1 && viewModel.isImplant
                    ? TextButton(
                        onPressed: viewModel.copyFromFirst,
                        child: const Text('Repetir o primeiro'),
                      )
                    : null,
              ),
              const SizedBox(height: 8),
              for (final tooth in viewModel.pillars) ...[
                _ToothCard(
                  viewModel: viewModel,
                  tooth: tooth,
                  expanded: tooth == viewModel.pillars.first,
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 8),
              AppSectionHeader(
                title: 'Retornos',
                subtitle: viewModel.schedulesSurgicalReturns
                    ? 'Sutura em 7 dias · longo em ${viewModel.longMonths} meses.'
                    : 'Defina os retornos deste atendimento. Sutura e osseointegração não são criadas automaticamente.',
              ),
              const SizedBox(height: 8),
              ..._chronologicalReturnEditors(viewModel),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => viewModel.addExtraReturn(ReturnReason.controle),
                icon: const Icon(Icons.add),
                label: const Text('Retorno de controle'),
              ),
              if (viewModel.schedulesSurgicalReturns) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => viewModel.addExtraReturn(ReturnReason.reabertura),
                  icon: const Icon(Icons.add),
                  label: const Text('Retorno para reabertura'),
                ),
              ],
            ],
          ),
        ),
        AppFooterBar(
          secondaryLabel: 'Voltar',
          primaryLabel: 'Salvar',
          onSecondary: viewModel.backToMouth,
          onPrimary: () {
            final error = viewModel.saveError;
            if (error != null) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
              return;
            }
            final created = viewModel.save();
            context.pop();
            if (created.length == 1) context.push('/procedures/${created.first.id}');
          },
        ),
      ],
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.viewModel});

  final NewProcedureViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              viewModel.draftLabel,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            _DateTile(
              icon: Icons.event_outlined,
              label: viewModel.isProsthesis ? 'Instalação' : 'Cirurgia',
              value: formatDay(viewModel.surgery),
              onTap: () => _pickDate(context, viewModel.surgery, viewModel.setSurgery),
            ),
          ],
        ),
      ),
    );
  }
}

class _PonticCard extends StatelessWidget {
  const _PonticCard({required this.teeth});

  final List<int> teeth;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Pônticos sem peça: ${teeth.join(', ')}'),
      ),
    );
  }
}

class _ToothCard extends StatelessWidget {
  const _ToothCard({
    required this.viewModel,
    required this.tooth,
    required this.expanded,
  });

  final NewProcedureViewModel viewModel;
  final int tooth;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    watchClinicalCatalog(context);
    final draft = viewModel.drafts[tooth]!;
    final modality = viewModel.modality!;
    final linked = viewModel.isProsthesis ? viewModel.linkedImplantsForTooth(tooth) : const <InstalledImplant>[];
    final pieceLine = [
      draft.manufacturer,
      draft.model,
    ].where((part) => part.isNotEmpty).join(' ');
    final prosthesisSubtitle = linked.isEmpty
        ? 'Sem implante vinculado nesta região'
        : linked.map((item) => item.subtitle).join(' · ');
    return AppCollapseCard(
      title: viewModel.subtype == ProcedureSubtype.protocolo ? 'Região $tooth' : 'Dente $tooth',
      subtitle: viewModel.isProsthesis
          ? prosthesisSubtitle
          : (pieceLine.isEmpty ? 'Rastreio opcional' : pieceLine),
      initiallyExpanded: expanded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (viewModel.isProsthesis) ...[
            if (linked.isEmpty)
              const AppEmptyHint(
                'Nenhum implante vinculado aqui. Marque um acima, se houver, ou salve sem vínculo.',
              )
            else
              for (final implant in linked) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(implant.title),
                  subtitle: Text(
                    [
                      implant.subtitle,
                      if (implant.lot.isNotEmpty) 'Lote ${implant.lot}',
                      if (implant.notes.isNotEmpty) implant.notes,
                    ].where((part) => part.isNotEmpty).join('\n'),
                  ),
                  isThreeLine: true,
                ),
              ],
          ],
          if (viewModel.isImplant) ...[
            _ManufacturerField(viewModel: viewModel, tooth: tooth),
            const SizedBox(height: 12),
            _ModelOrReferenceField(viewModel: viewModel, tooth: tooth),
            if (draft.reference.isNotEmpty || draft.anvisa.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                [
                  if (draft.reference.isNotEmpty) 'Ref. ${draft.reference}',
                  if (draft.anvisa.isNotEmpty) 'ANVISA ${draft.anvisa}',
                ].join(' · '),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            PresetDropdown(
              label: 'Tamanho',
              value: draft.size,
              options: implantSizes,
              onChanged: (value) => viewModel.updateDraft(tooth, (item) => item.size = value),
            ),
            const SizedBox(height: 4),
            _DateTile(
              icon: Icons.precision_manufacturing_outlined,
              label: 'Fabricação',
              value: draft.manufacturedOn == null ? 'Informar' : formatDay(draft.manufacturedOn!),
              onTap: () => _pickDate(
                context,
                draft.manufacturedOn ?? DateTime.now(),
                (value) => viewModel.updateDraft(tooth, (item) => item.manufacturedOn = value),
              ),
            ),
            _DateTile(
              icon: Icons.event_available_outlined,
              label: 'Validade',
              value: draft.expiresOn == null ? 'Informar' : formatDay(draft.expiresOn!),
              onTap: () => _pickDate(
                context,
                draft.expiresOn ?? DateTime.now(),
                (value) => viewModel.updateDraft(tooth, (item) => item.expiresOn = value),
              ),
            ),
          ],
          if (modality == Modality.enxerto || (viewModel.isImplant && viewModel.associatedGraft))
            _GraftFields(viewModel: viewModel, tooth: tooth),
        ],
      ),
    );
  }
}

class _ManufacturerField extends StatelessWidget {
  const _ManufacturerField({
    required this.viewModel,
    required this.tooth,
  });

  final NewProcedureViewModel viewModel;
  final int tooth;

  @override
  Widget build(BuildContext context) {
    watchClinicalCatalog(context);
    final draft = viewModel.drafts[tooth]!;
    return PresetDropdown(
      label: 'Fabricante',
      value: draft.manufacturer,
      options: implantCatalog.keys.toList(),
      onChanged: (value) => viewModel.updateDraft(tooth, (item) {
        item.manufacturer = value;
        item.clearCatalogFields();
      }),
    );
  }
}

class _ModelOrReferenceField extends StatelessWidget {
  const _ModelOrReferenceField({
    required this.viewModel,
    required this.tooth,
  });

  final NewProcedureViewModel viewModel;
  final int tooth;

  @override
  Widget build(BuildContext context) {
    watchClinicalCatalog(context);
    final draft = viewModel.drafts[tooth]!;
    return PresetDropdown(
      label: 'Modelo',
      value: draft.model,
      options: modelOrReferenceOptions(draft.manufacturer),
      hintText: 'Buscar modelo ou referência',
      enabled: draft.manufacturer.isNotEmpty,
      latentEntriesForQuery: (query) => implantReferenceMenuEntries(draft.manufacturer, query),
      onChanged: (value) {
        late final ImplantCatalogLookup result;
        viewModel.updateDraft(tooth, (item) {
          result = item.selectModelOrReference(value);
        });
        if (result == ImplantCatalogLookup.notFound && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Referência não encontrada para este fabricante. Corrija o valor.'),
            ),
          );
        }
      },
    );
  }
}

class _GraftFields extends StatelessWidget {
  const _GraftFields({required this.viewModel, required this.tooth});

  final NewProcedureViewModel viewModel;
  final int tooth;

  @override
  Widget build(BuildContext context) {
    final draft = viewModel.drafts[tooth]!;
    return GraftMaterialFields(
      grafts: draft.grafts,
      onChanged: () => viewModel.updateDraft(tooth, (_) {}),
      onAdd: () => viewModel.addGraft(tooth),
      onRemove: (index) => viewModel.removeGraft(tooth, index),
    );
  }
}

Future<void> _setAssociatedGraft(BuildContext context, bool value) async {
  final viewModel = context.read<NewProcedureViewModel>();
  if (!value && viewModel.associatedGraftHasData) {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover o enxerto'),
        content: const Text('Os dados do enxerto associado serão descartados.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remover')),
        ],
      ),
    );
    if (discard == true) viewModel.setAssociatedGraft(false, discard: true);
    return;
  }
  viewModel.setAssociatedGraft(value);
}

List<Widget> _chronologicalReturnEditors(NewProcedureViewModel viewModel) {
  final editors = <Widget>[
    if (viewModel.schedulesSurgicalReturns) ...[
      _ReturnEditor(
        title: 'Sutura',
        date: viewModel.suture,
        onDate: viewModel.setSuture,
      ),
      _ReturnEditor(
        title: 'Retorno longo',
        date: viewModel.longReturn,
        enabled: viewModel.longReminder,
        daysBefore: viewModel.longLead,
        onDate: viewModel.setLongReturn,
        onEnabled: viewModel.setLongReminder,
        onDaysBefore: viewModel.setLongLead,
      ),
    ],
    for (final extra in viewModel.extraReturns)
      _ReturnEditor(
        key: ValueKey(extra.id),
        title: returnReasonLabel(extra.reason),
        date: extra.date,
        enabled: extra.reminderEnabled,
        daysBefore: extra.reminderDaysBefore,
        onDate: (value) => viewModel.setExtraDate(extra.id, value),
        onEnabled: (value) => viewModel.setExtraReminder(extra.id, value),
        onDaysBefore: (value) => viewModel.setExtraLead(extra.id, value),
        onRemove: () => viewModel.removeExtraReturn(extra.id),
      ),
  ];
  return [
    for (var index = 0; index < editors.length; index++) ...[
      if (index > 0) const SizedBox(height: 12),
      editors[index],
    ],
  ];
}

class _ReturnEditor extends StatelessWidget {
  const _ReturnEditor({
    super.key,
    required this.title,
    required this.date,
    required this.onDate,
    this.enabled,
    this.daysBefore,
    this.onEnabled,
    this.onDaysBefore,
    this.onRemove,
  });

  final String title;
  final DateTime date;
  final bool? enabled;
  final int? daysBefore;
  final ValueChanged<DateTime> onDate;
  final ValueChanged<bool>? onEnabled;
  final ValueChanged<int>? onDaysBefore;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reminding = enabled;
    final lead = daysBefore;
    final toggle = onEnabled;
    final changeLead = onDaysBefore;
    return Card(
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
                  if (onRemove != null)
                    IconButton(
                      tooltip: 'Remover retorno',
                      visualDensity: VisualDensity.compact,
                      onPressed: onRemove,
                      icon: const Icon(Icons.close),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Text(
                returnStatusLabel(ReturnStatus.agendado),
                style: theme.textTheme.bodySmall,
              ),
            ),
            _DateTile(
              icon: Icons.event_outlined,
              label: 'Data de retorno',
              value: formatDay(date),
              onTap: () => _pickDate(context, date, onDate),
            ),
            if (reminding != null && lead != null && toggle != null && changeLead != null) ...[
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                title: const Text('Lembrete'),
                value: reminding,
                onChanged: toggle,
              ),
              if (reminding) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                  child: Row(
                    children: [
                      for (final option in reminderLeadDayOptions) ...[
                        if (option != reminderLeadDayOptions.first) const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            showCheckmark: false,
                            label: SizedBox(
                              width: double.infinity,
                              child: Text(
                                reminderLeadChipLabel(option),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            selected: lead == option,
                            onSelected: (_) => changeLead(option),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: Text(
                    'Avisa em ${formatDay(dateOnly(date).subtract(Duration(days: lead)))}',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(label),
      subtitle: Text(value),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

Future<void> _pickDate(BuildContext context, DateTime current, ValueChanged<DateTime> onPicked) async {
  final picked = await showAppDatePicker(
    context: context,
    initialDate: current,
    firstDate: DateTime(2020),
    lastDate: DateTime(2040),
  );
  if (picked != null) onPicked(dateOnly(picked));
}
