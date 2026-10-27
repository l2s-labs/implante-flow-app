import 'package:flutter/material.dart';
import '../core/date_picker.dart';

import '../../domain/models.dart';
import '../core/catalog_scope.dart';
import '../core/preset_dropdown.dart';
import '../new_procedure/new_procedure_viewmodel.dart';

class GraftMaterialFields extends StatelessWidget {
  const GraftMaterialFields({
    super.key,
    required this.grafts,
    required this.onChanged,
    required this.onAdd,
    required this.onRemove,
  });

  final List<GraftDraft> grafts;
  final VoidCallback onChanged;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < grafts.length; index++) ...[
          const SizedBox(height: 8),
          Material(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _GraftCard(
                graft: grafts[index],
                index: index,
                canRemove: grafts.length > 1,
                onChanged: onChanged,
                onRemove: () => onRemove(index),
              ),
            ),
          ),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Outro enxerto'),
          ),
        ),
      ],
    );
  }
}

class _GraftCard extends StatelessWidget {
  const _GraftCard({
    required this.graft,
    required this.index,
    required this.canRemove,
    required this.onChanged,
    required this.onRemove,
  });

  final GraftDraft graft;
  final int index;
  final bool canRemove;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    watchClinicalCatalog(context);
    final choice = graft.materialChoice;
    final product = graftProductOf(graft.manufacturer, graft.model);
    final presentations = choice == GraftMaterialChoice.autogeno
        ? GraftPresentation.values
        : product?.presentations ?? GraftPresentation.values;
    final showGranulometry = choice == GraftMaterialChoice.liofilizado &&
        graft.presentation == GraftPresentation.po;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Enxerto ${index + 1}', style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            if (canRemove)
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onRemove,
                icon: const Icon(Icons.remove_circle_outline),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in GraftMaterialChoice.values)
              ChoiceChip(
                label: Text(graftMaterialChoiceLabel(option)),
                selected: choice == option,
                onSelected: (_) {
                  graft.selectMaterial(option);
                  onChanged();
                },
              ),
          ],
        ),
        if (choice != null) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final option in GraftPresentation.values)
                ChoiceChip(
                  label: Text(graftPresentationLabel(option)),
                  selected: graft.presentation == option,
                  onSelected: presentations.contains(option)
                      ? (_) {
                          graft.selectPresentation(option);
                          onChanged();
                        }
                      : null,
                ),
            ],
          ),
        ],
        if (choice == GraftMaterialChoice.liofilizado) ...[
          const SizedBox(height: 12),
          PresetDropdown(
            label: 'Fabricante',
            value: graft.manufacturer,
            options: graftManufacturers(),
            onChanged: (value) {
              graft.selectManufacturer(value);
              onChanged();
            },
          ),
          const SizedBox(height: 12),
          PresetDropdown(
            label: 'Modelo',
            value: graft.model,
            options: [for (final item in graftProductsOf(graft.manufacturer)) item.model],
            enabled: graft.manufacturer.isNotEmpty,
            onChanged: (value) {
              graft.selectModel(value);
              onChanged();
            },
          ),
          const SizedBox(height: 12),
          PresetDropdown(
            label: 'Tipo',
            value: graft.productType,
            options: product == null ? const [] : [product.type],
            enabled: product != null,
            onChanged: (_) {},
          ),
          if (showGranulometry) ...[
            const SizedBox(height: 12),
            PresetDropdown(
              label: 'Granulometria',
              value: graft.granulometry,
              options: product?.granulometries ?? const [],
              enabled: product != null && product.granulometries.isNotEmpty,
              onChanged: (value) {
                graft.selectGranulometry(value);
                onChanged();
              },
            ),
          ],
          _DateTile(
            icon: Icons.precision_manufacturing_outlined,
            label: 'Fabricação',
            value: graft.manufacturedOn == null ? 'Informar' : formatDay(graft.manufacturedOn!),
            onTap: () => _pickDate(context, graft.manufacturedOn, (value) {
              graft.manufacturedOn = value;
              onChanged();
            }),
          ),
          _DateTile(
            icon: Icons.event_available_outlined,
            label: 'Validade',
            value: graft.expiresOn == null ? 'Informar' : formatDay(graft.expiresOn!),
            onTap: () => _pickDate(context, graft.expiresOn, (value) {
              graft.expiresOn = value;
              onChanged();
            }),
          ),
        ],
        if (choice == GraftMaterialChoice.autogeno) ...[
          const SizedBox(height: 12),
          TextFormField(
            key: ValueKey('donor-$index'),
            initialValue: graft.donorSite,
            decoration: const InputDecoration(labelText: 'Região doadora'),
            onChanged: (value) {
              graft.donorSite = value;
              onChanged();
            },
          ),
        ],
      ],
    );
  }
}

class SinusLiftFields extends StatelessWidget {
  const SinusLiftFields({
    super.key,
    required this.sinusLift,
    required this.technique,
    required this.note,
    required this.onLift,
    required this.onTechnique,
    required this.onNote,
  });

  final bool sinusLift;
  final SinusLiftTechnique? technique;
  final String note;
  final ValueChanged<bool> onLift;
  final ValueChanged<SinusLiftTechnique> onTechnique;
  final ValueChanged<String> onNote;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Houve levantamento de seio?'),
          value: sinusLift,
          onChanged: onLift,
        ),
        if (sinusLift) ...[
          const SizedBox(height: 8),
          PresetDropdown(
            label: 'Tipo de levantamento de seio',
            value: technique == null ? '' : sinusLiftTechniqueLabel(technique!),
            options: [for (final item in SinusLiftTechnique.values) sinusLiftTechniqueLabel(item)],
            onChanged: (value) {
              onTechnique(
                SinusLiftTechnique.values.firstWhere(
                  (item) => sinusLiftTechniqueLabel(item) == value,
                ),
              );
            },
          ),
          if (technique == SinusLiftTechnique.outro) ...[
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('sinus-note'),
              initialValue: note,
              decoration: const InputDecoration(labelText: 'Outro tipo'),
              onChanged: onNote,
            ),
          ],
        ],
      ],
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
