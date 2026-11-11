import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/clinic_repository.dart';
import '../../data/services/clinic_api.dart';
import '../../domain/certificate.dart';
import '../../domain/models.dart';
import '../../domain/first_steps.dart';
import '../../domain/practice.dart';
import '../view_models.dart';
import '../core/cro_field.dart';
import '../core/phone_input_formatter.dart';

class FirstStepsScreen extends StatefulWidget {
  const FirstStepsScreen({super.key});

  @override
  State<FirstStepsScreen> createState() => _FirstStepsScreenState();
}

class _FirstStepsScreenState extends State<FirstStepsScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _phone;
  late final TextEditingController _cro;
  late final TextEditingController _clinic;
  late final TextEditingController _address;
  String? _locationId;
  String? _newLocationId;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final profile = context.read<ClinicRepository>().current.profile;
    _phone = TextEditingController(text: profile.phone);
    _cro = TextEditingController(text: formatCroInput(profile.cro));
    _clinic = TextEditingController();
    _address = TextEditingController();
    final active = profile.locations
        .where((location) => location.active)
        .toList();
    if (active.isNotEmpty) {
      _locationId =
          active.where((location) => location.isDefault).firstOrNull?.id ??
          active.first.id;
    }
  }

  @override
  void dispose() {
    _phone.dispose();
    _cro.dispose();
    _clinic.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final repository = context.read<ClinicRepository>();
    final session = context.read<SessionViewModel>();
    final profile = repository.current.profile;
    var locations = profile.locations;
    if (_locationId == null) {
      _newLocationId ??= repository.allocateId('loc');
      locations = addCareLocation(
        locations,
        CareLocation(
          id: _newLocationId!,
          name: _clinic.text.trim(),
          address: _address.text.trim(),
        ),
      );
      locations = setDefaultCareLocation(locations, _newLocationId!);
    } else {
      locations = setDefaultCareLocation(locations, _locationId!);
    }
    try {
      await session.completeFirstSteps(
        profile.copyWith(
          phone: brazilianPhoneDigits(_phone.text),
          cro: normalizeCro(_cro.text)!,
          locations: locations,
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ClinicApiException
              ? error.message
              : 'Não foi possível salvar seus dados. Tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hintStyle = TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.4));
    final active = context
        .read<ClinicRepository>()
        .current
        .profile
        .locations
        .where((location) => location.active)
        .toList();
    if (_locationId == null &&
        _newLocationId != null &&
        active.any((item) => item.id == _newLocationId)) {
      _locationId = _newLocationId;
    }
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            onPressed: _saving
                ? null
                : () => context.read<SessionViewModel>().signOut(),
            tooltip: 'Sair da conta',
            icon: const Icon(Icons.logout),
          ),
          TextButton(
            onPressed: _saving
                ? null
                : context.read<SessionViewModel>().skipFirstSteps,
            child: const Text('Fazer depois'),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                children: [
                  Text(
                    'PRIMEIROS PASSOS',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Vamos preparar seu consultório',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Complete seus dados para começar. Você poderá alterá-los no perfil quando quiser.',
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Seus dados profissionais',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [const ContactPhoneInputFormatter()],
                    decoration: InputDecoration(
                      labelText: 'Telefone com DDD',
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      hintText: '(00) 0 0000 0000',
                      hintStyle: hintStyle,
                    ),
                    validator: (value) => firstStepsValidPhone(value ?? '')
                        ? null
                        : 'Informe um telefone válido com DDD.',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _cro,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [const CroInputFormatter()],
                    decoration: InputDecoration(
                      labelText: 'CRO',
                      prefixText: 'CRO-',
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      hintText: '00000',
                      hintStyle: hintStyle,
                      helperText: 'Ex.: CRO-RJ 44731. Usado nos certificados.',
                    ),
                    validator: (value) => !firstStepsValidCro(value ?? '')
                        ? 'Informe a UF e o número do CRO.'
                        : null,
                  ),
                  const SizedBox(height: 28),
                  Text('Clínica padrão', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Ela será sugerida no cadastro de pacientes.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  if (active.isNotEmpty)
                    DropdownButtonFormField<String>(
                      initialValue: _locationId,
                      decoration: const InputDecoration(
                        labelText: 'Local de atendimento',
                      ),
                      items: [
                        for (final item in active)
                          DropdownMenuItem(
                            value: item.id,
                            child: Text(item.name),
                          ),
                      ],
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _locationId = value),
                    ),
                  if (active.isEmpty) ...[
                    TextFormField(
                      controller: _clinic,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nome da clínica ou consultório',
                      ),
                      validator: (value) => (value ?? '').trim().isEmpty
                          ? 'Informe o nome da clínica.'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _address,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Endereço (opcional)',
                      ),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? 'Salvando...' : 'Concluir cadastro'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
