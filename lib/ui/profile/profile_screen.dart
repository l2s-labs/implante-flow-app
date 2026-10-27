import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/services/cep_lookup.dart';
import '../../data/services/clinic_api.dart';
import '../../domain/models.dart';
import '../../domain/practice.dart';
import '../core/app_sheet.dart';
import '../core/brazilian_phone_field.dart';
import '../core/layout.dart';
import '../view_models.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.focusField});

  final String? focusField;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _croFocus = FocusNode();
  final _croKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.focusField == 'cro') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = _croKey.currentContext;
        if (target != null) {
          Scrollable.ensureVisible(
            target,
            duration: const Duration(milliseconds: 250),
            alignment: 0.1,
          );
        }
        _croFocus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _croFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ProfileViewModel>();
    final session = context.watch<SessionViewModel>();
    final profile = viewModel.profile;
    final scheme = Theme.of(context).colorScheme;
    final highlightCro = widget.focusField == 'cro';
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          AppSurfaceCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayDentistName(profile.name),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(profile.email, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: sanitizePersonName(profile.name),
                  decoration: const InputDecoration(
                    labelText: 'Nome',
                    hintText: 'Nome não informado',
                  ),
                  textCapitalization: TextCapitalization.words,
                  onChanged: viewModel.setName,
                ),
                const SizedBox(height: 12),
                BrazilianPhoneField(initial: profile.phone, onChanged: viewModel.setPhone),
                const SizedBox(height: 12),
                TextFormField(
                  key: _croKey,
                  focusNode: _croFocus,
                  initialValue: profile.cro,
                  decoration: InputDecoration(
                    labelText: 'CRO/UF',
                    hintText: 'SP 12345',
                    helperText: highlightCro ? 'Necessário para emitir certificado' : null,
                  ),
                  onChanged: viewModel.setCro,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const AppSectionHeader(
            title: 'Locais de atendimento',
            subtitle: 'O local padrão só é uma sugestão no cadastro de pacientes.',
          ),
          const SizedBox(height: 8),
          if (profile.locations.isEmpty)
            const AppEmptyHint('Nenhum local cadastrado.')
          else
            for (final location in profile.locations) ...[
              AppSurfaceCard(
                child: ListTile(
                  title: Text(location.name),
                  subtitle: Text(
                    [
                      if (location.address.isNotEmpty) location.address,
                      if (!location.active) 'Inativo',
                      if (location.isDefault) 'Padrão',
                    ].join(' · '),
                  ),
                  isThreeLine: location.address.isNotEmpty,
                  trailing: PopupMenuButton<String>(
                    onSelected: (action) => _locationAction(context, viewModel, location, action),
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'editar', child: Text('Editar')),
                      if (location.active && !location.isDefault)
                        const PopupMenuItem(value: 'padrao', child: Text('Definir como padrão')),
                      if (location.active)
                        const PopupMenuItem(value: 'inativar', child: Text('Inativar')),
                      if (!location.active)
                        const PopupMenuItem(value: 'reativar', child: Text('Reativar')),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _editLocation(context, viewModel),
              icon: const Icon(Icons.add),
              label: const Text('Adicionar local'),
            ),
          ),
          const SizedBox(height: 20),
          const AppSectionHeader(
            title: 'Lembrete do retorno',
            subtitle: 'O aviso sai antes da data de retorno. O padrão é 15 dias.',
          ),
          const SizedBox(height: 8),
          AppSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  title: const Text('Lembrar antes do retorno'),
                  value: profile.reminderEnabled,
                  onChanged: viewModel.setReminderEnabled,
                ),
                if (profile.reminderEnabled)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Row(
                      children: [
                        for (final days in reminderLeadDayOptions) ...[
                          if (days != reminderLeadDayOptions.first) const SizedBox(width: 8),
                          Expanded(
                            child: ChoiceChip(
                              showCheckmark: false,
                              label: SizedBox(
                                width: double.infinity,
                                child: Text(
                                  reminderLeadChipLabel(days),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              selected: profile.reminderDaysBefore == days,
                              onSelected: (_) => viewModel.setReminderDaysBefore(days),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                SwitchListTile(
                  title: const Text('E-mail'),
                  value: profile.emailChannel,
                  onChanged: viewModel.setEmailChannel,
                ),
                SwitchListTile(
                  title: const Text('Push'),
                  value: profile.pushChannel,
                  onChanged: viewModel.setPushChannel,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: session.busy ? null : session.signOut,
            icon: session.busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout),
            label: const Text('Sair'),
            style: OutlinedButton.styleFrom(
              foregroundColor: scheme.error,
              side: BorderSide(color: scheme.error),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _locationAction(
  BuildContext context,
  ProfileViewModel viewModel,
  CareLocation location,
  String action,
) async {
  switch (action) {
    case 'editar':
      await _editLocation(context, viewModel, location: location);
    case 'padrao':
      viewModel.makeDefaultLocation(location.id);
    case 'reativar':
      viewModel.reactivateLocation(location.id);
    case 'inativar':
      String? replacement;
      if (needsDefaultReplacement(viewModel.profile.locations, location.id)) {
        replacement = await _pickReplacement(context, viewModel.profile.locations, location.id);
        if (replacement == null) return;
      }
      viewModel.inactivateLocation(location.id, replacementId: replacement);
  }
}

Future<void> _editLocation(
  BuildContext context,
  ProfileViewModel viewModel, {
  CareLocation? location,
}) async {
  final draft = await showAppSheet<({String name, String address})>(
    context: context,
    builder: (context) => _LocationDialog(viewModel: viewModel, location: location),
  );
  if (draft == null || draft.name.isEmpty) return;
  if (location == null) {
    viewModel.addLocation(name: draft.name, address: draft.address);
  } else {
    viewModel.editLocation(id: location.id, name: draft.name, address: draft.address);
  }
}

class _LocationDialog extends StatefulWidget {
  const _LocationDialog({required this.viewModel, this.location});

  final ProfileViewModel viewModel;
  final CareLocation? location;

  @override
  State<_LocationDialog> createState() => _LocationDialogState();
}

class _LocationDialogState extends State<_LocationDialog> {
  late final name = TextEditingController(text: widget.location?.name ?? '');
  late final cep = TextEditingController();
  late final street = TextEditingController();
  late final number = TextEditingController();
  late final neighborhood = TextEditingController();
  late final city = TextEditingController();
  late final state = TextEditingController();
  late final complement = TextEditingController();
  var _lookingUp = false;
  String? _cepError;

  @override
  void initState() {
    super.initState();
    final existing = widget.location?.address.trim() ?? '';
    if (existing.isNotEmpty) {
      // Endereços antigos (texto livre) entram em rua até o usuário refazer via CEP.
      street.text = existing;
    }
  }

  @override
  void dispose() {
    name.dispose();
    cep.dispose();
    street.dispose();
    number.dispose();
    neighborhood.dispose();
    city.dispose();
    state.dispose();
    complement.dispose();
    super.dispose();
  }

  String get _composed => formatStructuredAddress(
        street: street.text,
        number: number.text,
        neighborhood: neighborhood.text,
        city: city.text,
        state: state.text,
        cep: cep.text,
        complement: complement.text,
      );

  bool get _dirty {
    final initialName = widget.location?.name ?? '';
    final initialAddress = widget.location?.address ?? '';
    return name.text.trim() != initialName || _composed != initialAddress;
  }

  Future<void> _lookupCep() async {
    final digits = digitsOnly(cep.text);
    if (digits.length != 8) {
      setState(() => _cepError = 'CEP inválido. Informe 8 dígitos.');
      return;
    }
    setState(() {
      _lookingUp = true;
      _cepError = null;
    });
    try {
      final found = await widget.viewModel.lookupCep(digits);
      if (!mounted) return;
      setState(() {
        street.text = found.street;
        neighborhood.text = found.neighborhood;
        city.text = found.city;
        state.text = found.state;
        cep.text = formatCepInput(found.cep);
        _lookingUp = false;
      });
    } on ClinicApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _lookingUp = false;
        _cepError = cepErrorMessage(
          statusCode: error.statusCode,
          code: error.code,
          fallback: error.message,
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _lookingUp = false;
        _cepError = 'Não foi possível consultar o CEP.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      title: widget.location == null ? 'Novo local' : 'Editar local',
      dirty: _dirty,
      footer: AppSheetActions(
        onSave: () => AppSheet.pop(context, (name: name.text.trim(), address: _composed)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Nome'),
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: cep,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'CEP',
                    hintText: '00000-000',
                    errorText: _cepError,
                  ),
                  onChanged: (value) {
                    final formatted = formatCepInput(value);
                    if (formatted != value) {
                      cep.value = TextEditingValue(
                        text: formatted,
                        selection: TextSelection.collapsed(offset: formatted.length),
                      );
                    }
                    setState(() => _cepError = null);
                    if (digitsOnly(formatted).length == 8) {
                      _lookupCep();
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _lookingUp
                    ? const SizedBox(
                        width: 40,
                        height: 40,
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        tooltip: 'Buscar CEP',
                        onPressed: _lookingUp ? null : _lookupCep,
                        icon: const Icon(Icons.search),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: street,
            decoration: const InputDecoration(labelText: 'Rua'),
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: number,
            decoration: const InputDecoration(labelText: 'Número'),
            keyboardType: TextInputType.streetAddress,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: complement,
            decoration: const InputDecoration(labelText: 'Complemento'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: neighborhood,
            decoration: const InputDecoration(labelText: 'Bairro'),
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: city,
            decoration: const InputDecoration(labelText: 'Cidade'),
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: state,
            decoration: const InputDecoration(labelText: 'UF', hintText: 'SP'),
            textCapitalization: TextCapitalization.characters,
            maxLength: 2,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }
}

Future<String?> _pickReplacement(
  BuildContext context,
  List<CareLocation> locations,
  String currentId,
) {
  final options = [
    for (final location in locations)
      if (location.active && location.id != currentId) location,
  ];
  return showAppSheet<String>(
    context: context,
    builder: (context) => AppSheet(
      title: 'Escolha o novo padrão',
      footer: Align(
        alignment: Alignment.centerLeft,
        child: TextButton(onPressed: () => AppSheet.pop(context), child: const Text('Cancelar')),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final location in options)
            ListTile(
              title: Text(location.name),
              onTap: () => AppSheet.pop(context, location.id),
            ),
        ],
      ),
    ),
  );
}
