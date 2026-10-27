import 'package:flutter/material.dart';
import '../core/date_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../domain/models.dart';
import '../../domain/queries.dart';
import '../core/filter_menu.dart';
import '../core/layout.dart';
import '../view_models.dart';

class ReportsQuerySync extends StatefulWidget {
  const ReportsQuerySync({super.key, required this.child});

  final Widget child;

  @override
  State<ReportsQuerySync> createState() => _ReportsQuerySyncState();
}

class _ReportsQuerySyncState extends State<ReportsQuerySync> {
  GoRouter? _router;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.of(context);
    if (!identical(router, _router)) {
      _router?.routerDelegate.removeListener(_syncFilter);
      _router = router;
      router.routerDelegate.addListener(_syncFilter);
    }
    _syncFilter();
  }

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_syncFilter);
    super.dispose();
  }

  void _syncFilter() {
    final uri = _router?.routerDelegate.currentConfiguration.uri;
    if (uri == null || uri.path != '/reports') return;
    final filtro = uri.queryParameters['filtro'];
    if (filtro == null || !mounted) return;
    final requested = reportFilterFromName(filtro);
    final viewModel = context.read<ReportsViewModel>();
    if (viewModel.filter == requested) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || viewModel.filter == requested) return;
      viewModel.setFilter(requested);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ReportsViewModel>();
    final patients = viewModel.patients;
    final totals = viewModel.totals;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Relatórios'),
        actions: [
          FilterMenuButton(
            activeCount: viewModel.activeFilterCount,
            onClear: viewModel.clearFilters,
            groups: [
              FilterMenuGroup(
                title: 'Período',
                options: [
                  for (final span in ReportSpan.values)
                    FilterMenuOption(
                      label: reportSpanLabel(span),
                      selected: viewModel.span == span,
                      onSelected: () => viewModel.setSpan(span),
                    ),
                ],
              ),
              FilterMenuGroup(
                title: 'Modalidade',
                options: [
                  FilterMenuOption(
                    label: 'Todas',
                    selected: viewModel.modality == null,
                    onSelected: () => viewModel.setModality(null),
                  ),
                  for (final modality in Modality.values)
                    FilterMenuOption(
                      label: modalityLabel(modality),
                      selected: viewModel.modality == modality,
                      onSelected: () => viewModel.setModality(modality),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        key: const ValueKey('reports-scroll'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(viewModel.attendanceLabel),
          const SizedBox(height: 4),
          Text(
            'Em dia significa sem retorno vencido ainda agendado. Atraso não é falta.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (viewModel.loadError != null) ...[
            const SizedBox(height: 12),
            AppEmptyHint(viewModel.loadError!),
          ],
          const SizedBox(height: 12),
          SizedBox(
            height: 96,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _CountCard(
                  cardKey: const ValueKey('report-count-emDia'),
                  label: 'Em dia',
                  count: totals.onTrack,
                  selected: viewModel.filter == ReportFilter.emDia,
                  onTap: () => viewModel.setFilter(ReportFilter.emDia),
                ),
                _CountCard(
                  cardKey: const ValueKey('report-count-atrasados'),
                  label: 'Atrasados',
                  count: totals.overdue,
                  selected: viewModel.filter == ReportFilter.atrasados,
                  onTap: () => viewModel.setFilter(ReportFilter.atrasados),
                ),
                _CountCard(
                  cardKey: const ValueKey('report-count-faltas'),
                  label: 'Faltas registradas',
                  count: totals.absences,
                  selected: viewModel.filter == ReportFilter.faltas,
                  onTap: () => viewModel.setFilter(ReportFilter.faltas),
                ),
                _CountCard(
                  cardKey: const ValueKey('report-count-proximos'),
                  label: 'Próximos',
                  count: totals.upcoming,
                  selected: viewModel.filter == ReportFilter.proximos,
                  onTap: () => viewModel.setFilter(ReportFilter.proximos),
                ),
                _CountCard(
                  cardKey: const ValueKey('report-count-realizados'),
                  label: 'Realizados',
                  count: totals.completed,
                  selected: viewModel.filter == ReportFilter.realizados,
                  onTap: () => viewModel.setFilter(ReportFilter.realizados),
                ),
              ],
            ),
          ),
          if (viewModel.span == ReportSpan.personalizado) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _DateButton(
                    label: 'De',
                    value: viewModel.customStart,
                    onPick: viewModel.setCustomStart,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _DateButton(
                    label: 'Até',
                    value: viewModel.customEnd,
                    onPick: viewModel.setCustomEnd,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: 'Buscar paciente',
            ),
            onChanged: viewModel.setQuery,
          ),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: false, label: Text('Pacientes')),
              ButtonSegment(value: true, label: Text('Compromissos')),
            ],
            selected: {viewModel.byAppointment},
            onSelectionChanged: (value) => viewModel.setByAppointment(value.first),
          ),
          const SizedBox(height: 16),
          if (viewModel.byAppointment)
            _AppointmentList(viewModel: viewModel)
          else if (patients.isEmpty)
            AppEmptyHint(_emptyLabel(viewModel.filter))
          else
            for (final patient in viewModel.visiblePatients) ...[
              _PatientReportCard(viewModel: viewModel, patient: patient),
              const SizedBox(height: 8),
            ],
          if (viewModel.hasMore)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(onPressed: viewModel.showMore, child: const Text('Mostrar mais')),
            ),
        ],
      ),
    );
  }

  String _emptyLabel(ReportFilter filter) => switch (filter) {
        ReportFilter.emDia => 'Nenhum paciente em dia.',
        ReportFilter.atrasados => 'Nenhum paciente em atraso.',
        ReportFilter.faltas => 'Nenhum paciente com falta.',
        ReportFilter.proximos => 'Nenhum retorno próximo.',
        ReportFilter.realizados => 'Nenhuma consulta realizada.',
      };
}

class _CountCard extends StatelessWidget {
  const _CountCard({
    required this.cardKey,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final Key cardKey;
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: SizedBox(
        width: 148,
        child: Semantics(
          key: cardKey,
          button: true,
          selected: selected,
          label: label,
          child: AppSurfaceCard(
            color: selected ? scheme.primaryContainer : null,
            onTap: onTap,
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('$count', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({required this.label, required this.value, required this.onPick});

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: () async {
        final picked = await showAppDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2040),
        );
        if (picked != null) onPick(dateOnly(picked));
      },
      child: Text(value == null ? label : '$label ${formatDay(value!)}'),
    );
  }
}

class _AppointmentList extends StatelessWidget {
  const _AppointmentList({required this.viewModel});

  final ReportsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final rows = viewModel.visibleAppointments;
    if (rows.isEmpty) return const AppEmptyHint('Nenhum compromisso nesse recorte.');
    return Column(
      children: [
        for (final row in rows) ...[
          AppSurfaceCard(
            child: ListTile(
              title: Text(row.patient.name),
              subtitle: Text(
                '${formatDay(row.followUp.date)} · ${returnReasonLabel(row.followUp.reason)} · ${row.procedure.teethLabel}',
              ),
              trailing: IconButton(
                tooltip: 'Prontuário',
                onPressed: () => context.push('/patients/${row.patient.id}'),
                icon: const Icon(Icons.folder_shared_outlined),
              ),
              onTap: () => context.push('/procedures/${row.procedure.id}'),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _PatientReportCard extends StatelessWidget {
  const _PatientReportCard({required this.viewModel, required this.patient});

  final ReportsViewModel viewModel;
  final Patient patient;

  @override
  Widget build(BuildContext context) {
    final rows = viewModel.rowsFor(patient.id);
    final countLabel = switch (viewModel.filter) {
      ReportFilter.faltas => rows.length == 1 ? '1 falta' : '${rows.length} faltas',
      ReportFilter.emDia when rows.isEmpty => 'Sem pendência vencida',
      _ => rows.length == 1 ? '1 compromisso' : '${rows.length} compromissos',
    };
    return AppSurfaceCard(
      child: Column(
        children: [
          ListTile(
            title: Text(patient.name),
            subtitle: Text(countLabel),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/patients/${patient.id}'),
          ),
          for (final row in rows)
            ListTile(
              dense: true,
              title: Text('${formatDay(row.followUp.date)} · ${returnReasonLabel(row.followUp.reason)}'),
              subtitle: Text('${row.procedure.teethLabel} · ${returnStatusLabel(row.followUp.status)}'),
              onTap: () => context.push('/procedures/${row.procedure.id}'),
            ),
        ],
      ),
    );
  }
}
