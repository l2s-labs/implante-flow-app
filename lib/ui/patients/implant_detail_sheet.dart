import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../core/app_sheet.dart';

/// Ação escolhida no detalhe de um implante instalado.
enum ImplantDetailAction { edit, viewProcedure }

/// Detalhe de leitura de um único implante (L2S-81). O tap no card do perfil
/// abre este sheet; edição e procedimento de origem ficam como ações.
Future<ImplantDetailAction?> showImplantDetailSheet(
  BuildContext context, {
  required InstalledImplant implant,
}) {
  return showAppSheet<ImplantDetailAction>(
    context: context,
    builder: (context) => _ImplantDetailSheet(implant: implant),
  );
}

class _ImplantDetailSheet extends StatelessWidget {
  const _ImplantDetailSheet({required this.implant});

  final InstalledImplant implant;

  @override
  Widget build(BuildContext context) {
    final piece = <(String, String)>[
      ('Fabricante', implant.manufacturer),
      ('Modelo / referência', implant.model),
      ('Tamanho', implant.size),
      ('Lote', implant.lot),
    ].where((field) => field.$2.trim().isNotEmpty).toList();
    final installation = <(String, String)>[
      (
        'Data da instalação',
        implant.installedOn == null
            ? 'Não informada'
            : formatDay(implant.installedOn!),
      ),
      if (implant.originClinic.trim().isNotEmpty)
        ('Clínica / profissional de origem', implant.originClinic),
    ];
    final notes = implant.notes.trim();

    return AppSheet(
      title: 'Implante · Dente ${implant.fdi}',
      footer: FilledButton.icon(
        onPressed: () => AppSheet.pop(context, ImplantDetailAction.edit),
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Editar'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text(implantOriginLabel(implant.origin))),
              if (!implant.active) const Chip(label: Text('Inativo')),
            ],
          ),
          if (piece.isNotEmpty) _FieldGroup(title: 'Peça', fields: piece),
          _FieldGroup(title: 'Instalação', fields: installation),
          if (notes.isNotEmpty)
            _FieldGroup(title: 'Observações', fields: [('Observações', notes)]),
          if (implant.sourceProcedureId != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextButton.icon(
                  onPressed: () =>
                      AppSheet.pop(context, ImplantDetailAction.viewProcedure),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Ver procedimento de origem'),
                ),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _FieldGroup extends StatelessWidget {
  const _FieldGroup({required this.title, required this.fields});

  final String title;
  final List<(String, String)> fields;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          for (final field in fields)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(field.$1, style: theme.textTheme.bodySmall),
              subtitle: Text(field.$2, style: theme.textTheme.bodyLarge),
            ),
        ],
      ),
    );
  }
}
