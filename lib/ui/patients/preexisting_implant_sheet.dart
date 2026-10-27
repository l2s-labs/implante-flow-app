import 'package:flutter/material.dart';
import '../core/date_picker.dart';
import 'package:flutter/services.dart';

import '../../domain/models.dart';
import '../core/app_sheet.dart';

Future<PreexistingImplantDraft?> showPreexistingImplantSheet(
  BuildContext context, {
  InstalledImplant? initial,
  bool allowInactive = false,
}) {
  return showAppSheet<PreexistingImplantDraft>(
    context: context,
    builder: (context) => _PreexistingImplantSheet(
      initial: initial,
      allowInactive: allowInactive,
    ),
  );
}

class _PreexistingImplantSheet extends StatefulWidget {
  const _PreexistingImplantSheet({this.initial, this.allowInactive = false});

  final InstalledImplant? initial;
  final bool allowInactive;

  @override
  State<_PreexistingImplantSheet> createState() => _PreexistingImplantSheetState();
}

class _PreexistingImplantSheetState extends State<_PreexistingImplantSheet> {
  late final fdi = TextEditingController(text: widget.initial?.fdi.toString() ?? '');
  late final manufacturer = TextEditingController(text: widget.initial?.manufacturer ?? '');
  late final model = TextEditingController(text: widget.initial?.model ?? '');
  late final size = TextEditingController(text: widget.initial?.size ?? '');
  late final lot = TextEditingController(text: widget.initial?.lot ?? '');
  late final originClinic = TextEditingController(text: widget.initial?.originClinic ?? '');
  late final notes = TextEditingController(text: widget.initial?.notes ?? '');
  late DateTime? installedOn = widget.initial?.installedOn;
  late bool active = widget.initial?.active ?? true;

  @override
  void dispose() {
    fdi.dispose();
    manufacturer.dispose();
    model.dispose();
    size.dispose();
    lot.dispose();
    originClinic.dispose();
    notes.dispose();
    super.dispose();
  }

  bool get _valid {
    final tooth = int.tryParse(fdi.text.trim());
    return tooth != null && tooth > 0;
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initial != null;
    final lockedFdi = editing && widget.initial!.origin == ImplantOrigin.procedureRecorded;
    return AppSheet(
      title: editing ? 'Editar implante' : 'Implante preexistente',
      dirty: true,
      footer: AppSheetActions(
        onSave: () {
          if (!_valid) return;
          AppSheet.pop(
            context,
            PreexistingImplantDraft(
              fdi: int.parse(fdi.text.trim()),
              manufacturer: manufacturer.text.trim(),
              model: model.text.trim(),
              size: size.text.trim(),
              lot: lot.text.trim(),
              installedOn: installedOn,
              originClinic: originClinic.text.trim(),
              notes: notes.text.trim(),
              active: active,
            ),
          );
        },
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            editing
                ? implantOriginLabel(widget.initial!.origin)
                : 'Origem: Preexistente / histórico informado',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: fdi,
            enabled: !lockedFdi,
            decoration: const InputDecoration(labelText: 'Dente (FDI)'),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: manufacturer,
            decoration: const InputDecoration(labelText: 'Fabricante (opcional)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: model,
            decoration: const InputDecoration(labelText: 'Modelo / referência (opcional)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: size,
            decoration: const InputDecoration(labelText: 'Tamanho (opcional)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: lot,
            decoration: const InputDecoration(labelText: 'Lote (opcional)'),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Data aproximada da instalação'),
            subtitle: Text(installedOn == null ? 'Não informada' : formatDay(installedOn!)),
            trailing: TextButton(
              onPressed: () async {
                final picked = await showAppDatePicker(
                  context: context,
                  initialDate: installedOn ?? DateTime.now(),
                  firstDate: DateTime(1990),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked == null) return;
                setState(() => installedOn = picked);
              },
              child: const Text('Informar'),
            ),
          ),
          TextField(
            controller: originClinic,
            decoration: const InputDecoration(labelText: 'Clínica / profissional de origem (opcional)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: notes,
            decoration: const InputDecoration(labelText: 'Observações (opcional)'),
            maxLines: 3,
          ),
          if (widget.allowInactive && editing) ...[
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Ativo na ficha'),
              value: active,
              onChanged: (value) => setState(() => active = value),
            ),
          ],
        ],
      ),
    );
  }
}
