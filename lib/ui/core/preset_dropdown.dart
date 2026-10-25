import 'package:flutter/material.dart';

import '../../domain/models.dart';

const _referenceValuePrefix = '\u{200B}ref:';

/// Altura preferida do painel; nunca passa do espaço sob o campo (evita flip para cima).
const _preferredMenuHeight = 210.0;
const _minMenuHeight = 80.0;

const _menuStyle = MenuStyle(
  alignment: AlignmentDirectional.bottomStart,
);

double _menuHeightFor(BuildContext context) {
  final media = MediaQuery.of(context);
  final box = context.findRenderObject() as RenderBox?;
  if (box == null || !box.hasSize) return _preferredMenuHeight;

  final fieldBottom = box.localToGlobal(Offset(0, box.size.height)).dy;
  final usableBottom = media.size.height - media.viewInsets.bottom;
  final availableBelow = usableBottom - fieldBottom - 8;
  if (!availableBelow.isFinite || availableBelow <= 0) return _minMenuHeight;
  // Cabe sempre abaixo → o MenuAnchor não precisa abrir para cima.
  return availableBelow.clamp(_minMenuHeight, _preferredMenuHeight);
}

void _dismissFieldFocus() {
  FocusManager.instance.primaryFocus?.unfocus();
  // O DropdownMenu pode devolver o foco ao TextField no mesmo frame.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    FocusManager.instance.primaryFocus?.unfocus();
  });
}

bool _isReferenceMenuValue(String value) => value.startsWith(_referenceValuePrefix);

String encodeReferenceMenuValue(String reference) => '$_referenceValuePrefix$reference';

String? decodeReferenceMenuValue(String value) {
  if (!_isReferenceMenuValue(value)) return null;
  return value.substring(_referenceValuePrefix.length);
}

class PresetDropdown extends StatelessWidget {
  const PresetDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.enabled = true,
    this.hintText,
    this.latentEntriesForQuery,
  });

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;
  final bool enabled;
  final String? hintText;

  /// Entradas extras só enquanto há texto de busca (ex.: referências).
  /// Com filtro vazio, a listagem mostra apenas [options] (modelos únicos).
  final List<DropdownMenuEntry<String>> Function(String query)? latentEntriesForQuery;

  @override
  Widget build(BuildContext context) {
    if (latentEntriesForQuery != null) {
      return _FilteringPresetDropdown(
        label: label,
        value: value,
        options: options,
        onChanged: onChanged,
        enabled: enabled,
        hintText: hintText,
        latentEntriesForQuery: latentEntriesForQuery!,
      );
    }
    return _StaticPresetDropdown(
      label: label,
      value: value,
      options: options,
      onChanged: onChanged,
      enabled: enabled,
      hintText: hintText,
    );
  }
}

class _StaticPresetDropdown extends StatelessWidget {
  const _StaticPresetDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    required this.enabled,
    this.hintText,
  });

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;
  final bool enabled;
  final String? hintText;

  @override
  Widget build(BuildContext context) {
    final items = withCurrentOption(options, value);
    final current = items.contains(value) ? value : null;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite ? constraints.maxWidth : null;
        return DropdownMenu<String>(
          key: ValueKey('$label-${items.join()}-$value-$enabled'),
          enabled: enabled,
          width: width,
          menuHeight: _menuHeightFor(context),
          menuStyle: _menuStyle,
          initialSelection: current,
          label: Text(label),
          hintText: enabled ? (hintText ?? 'Buscar') : null,
          enableFilter: true,
          requestFocusOnTap: enabled,
          inputDecorationTheme: Theme.of(context).inputDecorationTheme,
          dropdownMenuEntries: [
            for (final name in items) DropdownMenuEntry(value: name, label: name),
          ],
          filterCallback: (entries, filter) {
            final query = filter.trim().toLowerCase();
            if (query.isEmpty) return entries;
            return [
              for (final entry in entries)
                if (entry.label.toLowerCase().contains(query)) entry,
            ];
          },
          onSelected: enabled
              ? (selected) {
                  if (selected == null) return;
                  onChanged(selected);
                  _dismissFieldFocus();
                }
              : null,
        );
      },
    );
  }
}

class _FilteringPresetDropdown extends StatefulWidget {
  const _FilteringPresetDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    required this.enabled,
    required this.latentEntriesForQuery,
    this.hintText,
  });

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;
  final bool enabled;
  final String? hintText;
  final List<DropdownMenuEntry<String>> Function(String query) latentEntriesForQuery;

  @override
  State<_FilteringPresetDropdown> createState() => _FilteringPresetDropdownState();
}

class _FilteringPresetDropdownState extends State<_FilteringPresetDropdown> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _controller.addListener(_onQueryChanged);
  }

  @override
  void didUpdateWidget(covariant _FilteringPresetDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && _controller.text != widget.value) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onQueryChanged)
      ..dispose();
    super.dispose();
  }

  void _onQueryChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final items = withCurrentOption(widget.options, widget.value);
    final query = _controller.text.trim();
    final latents = query.isEmpty ? const <DropdownMenuEntry<String>>[] : widget.latentEntriesForQuery(query);
    final menuEntries = [
      for (final name in items) DropdownMenuEntry<String>(value: name, label: name),
      ...latents,
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite ? constraints.maxWidth : null;
        return DropdownMenu<String>(
          key: ValueKey('${widget.label}-${items.join()}-${widget.enabled}'),
          enabled: widget.enabled,
          width: width,
          menuHeight: _menuHeightFor(context),
          menuStyle: _menuStyle,
          controller: _controller,
          initialSelection: items.contains(widget.value) ? widget.value : null,
          label: Text(widget.label),
          hintText: widget.enabled ? (widget.hintText ?? 'Buscar') : null,
          enableFilter: true,
          requestFocusOnTap: widget.enabled,
          inputDecorationTheme: Theme.of(context).inputDecorationTheme,
          dropdownMenuEntries: menuEntries,
          filterCallback: (entries, filter) {
            final text = filter.trim();
            if (text.isEmpty) {
              return [
                for (final entry in entries)
                  if (!_isReferenceMenuValue(entry.value)) entry,
              ];
            }
            final lower = text.toLowerCase();
            final models = [
              for (final entry in entries)
                if (!_isReferenceMenuValue(entry.value) && entry.label.toLowerCase().contains(lower))
                  entry,
            ];
            final refs = [
              for (final entry in entries)
                if (_isReferenceMenuValue(entry.value)) entry,
            ];
            return [...models, ...refs];
          },
          onSelected: widget.enabled
              ? (selected) {
                  if (selected == null) return;
                  widget.onChanged(decodeReferenceMenuValue(selected) ?? selected);
                  _dismissFieldFocus();
                }
              : null,
        );
      },
    );
  }
}

/// Referências do fabricante que batem com a busca (prefixo normalizado).
/// Rótulo = modelo (ou modelo · tamanho se houver mais de uma no resultado).
List<DropdownMenuEntry<String>> implantReferenceMenuEntries(String manufacturer, String query) {
  final matches = implantReferencesMatching(manufacturer, query);
  if (matches.isEmpty) return const [];
  final modelCounts = <String, int>{};
  for (final entry in matches) {
    modelCounts[entry.model] = (modelCounts[entry.model] ?? 0) + 1;
  }
  return [
    for (final entry in matches)
      DropdownMenuEntry(
        value: encodeReferenceMenuValue(entry.reference),
        label: (modelCounts[entry.model] ?? 0) > 1 && entry.size.isNotEmpty
            ? '${entry.model} · ${entry.size}'
            : entry.model,
      ),
  ];
}
