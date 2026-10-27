import 'package:flutter/material.dart';
import '../core/date_picker.dart';

import '../../domain/models.dart';
import '../core/catalog_scope.dart';
import '../core/layout.dart';
import '../core/preset_dropdown.dart';
import '../graft/graft_form.dart';
import '../new_procedure/new_procedure_viewmodel.dart';

typedef TraceabilityUpdate = ({
  List<ToothSite> sites,
  bool sinusLift,
  SinusLiftTechnique? sinusLiftTechnique,
  String sinusLiftNote,
});

Future<TraceabilityUpdate?> editTraceability(
  BuildContext context, {
  required Procedure procedure,
}) {
  return Navigator.of(context, rootNavigator: true).push<TraceabilityUpdate>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (context) => TraceabilityEditorPage(procedure: procedure),
    ),
  );
}

class TraceabilityEditorPage extends StatefulWidget {
  const TraceabilityEditorPage({super.key, required this.procedure});

  final Procedure procedure;

  @override
  State<TraceabilityEditorPage> createState() => _TraceabilityEditorPageState();
}

class _TraceabilityEditorPageState extends State<TraceabilityEditorPage> {
  late final Map<int, PieceDraft> drafts = {
    for (final site in widget.procedure.sites)
      if (site.role == ToothRole.pilar) site.fdi: PieceDraft.fromSite(site),
  };
  late bool _sinusLift = widget.procedure.sinusLift;
  late SinusLiftTechnique? _sinusTechnique = widget.procedure.sinusLiftTechnique;
  late String _sinusNote = widget.procedure.sinusLiftNote;

  bool get _showImplant => widget.procedure.modality == Modality.implante;

  bool get _asksSinusLift =>
      widget.procedure.modality == Modality.enxerto || widget.procedure.associatedGraft;

  void _save() {
    final issue = sinusLiftIssue(
      applies: _asksSinusLift,
      sinusLift: _sinusLift,
      technique: _sinusTechnique,
      note: _sinusNote,
    );
    if (issue != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(issue)));
      return;
    }
    Navigator.pop(context, (
      sites: [
        for (final site in widget.procedure.sites)
          ToothSite(
            fdi: site.fdi,
            role: site.role,
            piece: site.role == ToothRole.pontico || !_showImplant
                ? null
                : ImplantPiece(
                    manufacturer: drafts[site.fdi]?.manufacturer ?? '',
                    model: drafts[site.fdi]?.model ?? '',
                    reference: drafts[site.fdi]?.reference ?? '',
                    size: drafts[site.fdi]?.size ?? '',
                    lot: drafts[site.fdi]?.lot ?? '',
                    anvisa: drafts[site.fdi]?.anvisa ?? '',
                    manufacturedOn: drafts[site.fdi]?.manufacturedOn,
                    expiresOn: drafts[site.fdi]?.expiresOn,
                  ),
            grafts: site.role == ToothRole.pontico
                ? const []
                : [
                    if (!_showImplant || (drafts[site.fdi]?.withGraft ?? false))
                      for (final graft in drafts[site.fdi]?.grafts ?? const <GraftDraft>[])
                        graft.toMaterial(),
                  ],
          ),
      ],
      sinusLift: _asksSinusLift && _sinusLift,
      sinusLiftTechnique: _asksSinusLift && _sinusLift ? _sinusTechnique : null,
      sinusLiftNote: _asksSinusLift && _sinusLift ? _sinusNote.trim() : '',
    ));
  }

  @override
  Widget build(BuildContext context) {
    final pillars = [
      for (final site in widget.procedure.sites)
        if (drafts.containsKey(site.fdi)) site,
    ];
    final pontics = [
      for (final site in widget.procedure.sites)
        if (site.role == ToothRole.pontico) site.fdi,
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Editar rastreio')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                AppSectionHeader(
                  title: widget.procedure.classificationLabel,
                  subtitle: 'Pode completar a peça agora ou deixar em branco.',
                ),
                if (pontics.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  AppSurfaceCard(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    padding: const EdgeInsets.all(16),
                    child: Text('Pônticos sem peça: ${pontics.join(', ')}'),
                  ),
                ],
                if (_asksSinusLift) ...[
                  const SizedBox(height: 12),
                  SinusLiftFields(
                    sinusLift: _sinusLift,
                    technique: _sinusTechnique,
                    note: _sinusNote,
                    onLift: (value) => setState(() {
                      _sinusLift = value;
                      if (!value) {
                        _sinusTechnique = null;
                        _sinusNote = '';
                      }
                    }),
                    onTechnique: (value) => setState(() {
                      _sinusTechnique = value;
                      if (value != SinusLiftTechnique.outro) _sinusNote = '';
                    }),
                    onNote: (value) => _sinusNote = value,
                  ),
                ],
                const SizedBox(height: 20),
                for (var index = 0; index < pillars.length; index++) ...[
                  _SiteCard(
                    site: pillars[index],
                    draft: drafts[pillars[index].fdi]!,
                    showImplant: _showImplant,
                    expanded: index == 0,
                    onChanged: () => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
          AppFooterBar(
            secondaryLabel: 'Cancelar',
            primaryLabel: 'Salvar',
            onSecondary: () => Navigator.pop(context),
            onPrimary: _save,
          ),
        ],
      ),
    );
  }
}

class _SiteCard extends StatelessWidget {
  const _SiteCard({
    required this.site,
    required this.draft,
    required this.showImplant,
    required this.expanded,
    required this.onChanged,
  });

  final ToothSite site;
  final PieceDraft draft;
  final bool showImplant;
  final bool expanded;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    watchClinicalCatalog(context);
    final pieceLine = [draft.manufacturer, draft.model].where((part) => part.isNotEmpty).join(' ');
    return AppCollapseCard(
      title: 'Dente ${site.fdi}',
      subtitle: pieceLine.isEmpty ? 'Rastreio opcional' : pieceLine,
      initiallyExpanded: expanded,
      child: Column(
        children: [
          if (showImplant) ...[
              PresetDropdown(
                label: 'Fabricante',
                value: draft.manufacturer,
                options: implantCatalog.keys.toList(),
                onChanged: (value) {
                  draft.manufacturer = value;
                  draft.clearCatalogFields();
                  onChanged();
                },
              ),
              const SizedBox(height: 16),
              PresetDropdown(
                label: 'Modelo',
                value: draft.model,
                options: modelOrReferenceOptions(draft.manufacturer),
                hintText: 'Buscar modelo ou referência',
                enabled: draft.manufacturer.isNotEmpty,
                latentEntriesForQuery: (query) => implantReferenceMenuEntries(draft.manufacturer, query),
                onChanged: (value) {
                  final result = draft.selectModelOrReference(value);
                  onChanged();
                  if (result == ImplantCatalogLookup.notFound && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Referência não encontrada para este fabricante. Corrija o valor.'),
                      ),
                    );
                  }
                },
              ),
              if (draft.reference.isNotEmpty || draft.anvisa.isNotEmpty) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    [
                      if (draft.reference.isNotEmpty) 'Ref. ${draft.reference}',
                      if (draft.anvisa.isNotEmpty) 'ANVISA ${draft.anvisa}',
                    ].join(' · '),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              PresetDropdown(
                label: 'Tamanho',
                value: draft.size,
                options: implantSizes,
                onChanged: (value) {
                  draft.size = value;
                  onChanged();
                },
              ),
              const SizedBox(height: 8),
              _DateTile(
                icon: Icons.precision_manufacturing_outlined,
                label: 'Fabricação',
                value: draft.manufacturedOn == null ? 'Informar' : formatDay(draft.manufacturedOn!),
                onTap: () => _pickDate(context, draft.manufacturedOn, (value) {
                  draft.manufacturedOn = value;
                  onChanged();
                }),
              ),
              _DateTile(
                icon: Icons.event_available_outlined,
                label: 'Validade',
                value: draft.expiresOn == null ? 'Informar' : formatDay(draft.expiresOn!),
                onTap: () => _pickDate(context, draft.expiresOn, (value) {
                  draft.expiresOn = value;
                  onChanged();
                }),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Com enxerto'),
                value: draft.withGraft,
                onChanged: (value) {
                  draft.withGraft = value;
                  onChanged();
                },
              ),
            ],
            if (!showImplant || draft.withGraft)
              GraftMaterialFields(
                grafts: draft.grafts,
                onChanged: onChanged,
                onAdd: () {
                  draft.grafts.add(GraftDraft());
                  onChanged();
                },
                onRemove: (index) {
                  if (draft.grafts.length <= 1) return;
                  draft.grafts.removeAt(index);
                  onChanged();
                },
              ),
        ],
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
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(label),
      subtitle: Text(value),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

Future<void> _pickDate(
  BuildContext context,
  DateTime? current,
  ValueChanged<DateTime> onPicked,
) async {
  final picked = await showAppDatePicker(
    context: context,
    initialDate: current ?? DateTime.now(),
    firstDate: DateTime(2020),
    lastDate: DateTime(2040),
  );
  if (picked != null) onPicked(dateOnly(picked));
}
