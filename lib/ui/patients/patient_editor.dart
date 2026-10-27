import 'package:flutter/material.dart';
import '../core/date_picker.dart';

import '../../domain/models.dart';
import '../../domain/practice.dart';
import '../core/brazilian_phone_field.dart';
import '../core/cpf_field.dart';
import '../core/layout.dart';

class PatientDraft {
  const PatientDraft({
    required this.name,
    required this.phone,
    this.email = '',
    required this.cpf,
    required this.birthDate,
    this.notes = '',
    required this.guardian,
    this.locationIds = const [],
    this.notifyByEmail = false,
    this.notifyByPhone = false,
  });

  final String name;
  final String phone;
  final String email;
  final String cpf;
  final DateTime birthDate;
  final String notes;
  final String guardian;
  final List<String> locationIds;
  final bool notifyByEmail;
  final bool notifyByPhone;
}

bool _minor(DateTime birthDate) => Patient(
      id: 'draft',
      name: 'draft',
      phone: '',
      birthDate: birthDate,
    ).isMinor;

Future<PatientDraft?> editPatientDraft(
  BuildContext context, {
  required String title,
  PatientDraft? initial,
  List<CareLocation> locations = const [],
}) {
  return Navigator.of(context, rootNavigator: true).push<PatientDraft>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (context) => PatientEditorPage(
        title: title,
        initial: initial,
        locations: locations,
      ),
    ),
  );
}

class PatientEditorPage extends StatefulWidget {
  const PatientEditorPage({
    super.key,
    required this.title,
    this.initial,
    this.locations = const [],
  });

  final String title;
  final PatientDraft? initial;
  final List<CareLocation> locations;

  @override
  State<PatientEditorPage> createState() => _PatientEditorPageState();
}

class _PatientEditorPageState extends State<PatientEditorPage> {
  late final TextEditingController name;
  late final TextEditingController email;
  late String cpf;
  late final TextEditingController guardian;
  late DateTime birth;
  late String phone;
  late Set<String> locationIds;
  late bool notifyByEmail;
  late bool notifyByPhone;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    name = TextEditingController(text: initial?.name ?? '');
    email = TextEditingController(text: initial?.email ?? '');
    phone = initial?.phone ?? '';
    cpf = initial?.cpf ?? '';
    guardian = TextEditingController(text: initial?.guardian ?? '');
    birth = initial?.birthDate ?? DateTime(1980, 1, 1);
    notifyByEmail = initial?.notifyByEmail ?? false;
    notifyByPhone = initial?.notifyByPhone ?? false;
    if (initial == null) {
      final suggested = defaultCareLocation(widget.locations);
      locationIds = suggested == null ? {} : {suggested.id};
    } else {
      locationIds = initial.locationIds.toSet();
    }
  }

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    guardian.dispose();
    super.dispose();
  }

  bool get _emailValid => isValidEmail(email.text);
  bool get _phoneValid => isValidBrazilianPhone(phone);

  bool get _canSave {
    final minor = _minor(birth);
    return name.text.trim().isNotEmpty &&
        emailIssue(email.text) == null &&
        brazilianPhoneIssue(phone) == null &&
        cpfIssue(cpf) == null &&
        (!minor || guardian.text.trim().isNotEmpty);
  }

  void _save() {
    Navigator.pop(
      context,
      PatientDraft(
        name: name.text,
        phone: digitsOnly(phone),
        email: email.text.trim(),
        cpf: digitsOnly(cpf),
        birthDate: birth,
        notes: widget.initial?.notes ?? '',
        guardian: _minor(birth) ? guardian.text : '',
        locationIds: [
          for (final location in widget.locations)
            if (locationIds.contains(location.id)) location.id,
        ],
        notifyByEmail: notifyByEmail && _emailValid,
        notifyByPhone: notifyByPhone && _phoneValid,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final minor = _minor(birth);
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                const AppSectionHeader(
                  title: 'Cadastro',
                  subtitle: 'Nome, contatos, CPF e nascimento.',
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Nome'),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'E-mail',
                    errorText: emailIssue(email.text),
                  ),
                  onChanged: (value) => setState(() {
                    if (!isValidEmail(value)) notifyByEmail = false;
                  }),
                ),
                const SizedBox(height: 20),
                BrazilianPhoneField(
                  initial: phone,
                  onChanged: (value) => setState(() {
                    phone = value;
                    if (!isValidBrazilianPhone(value)) notifyByPhone = false;
                  }),
                ),
                const SizedBox(height: 12),
                const AppSectionHeader(
                  title: 'Avisos de etapa',
                  subtitle: 'Usados só para atualizações das etapas do tratamento. Nada é marcado sozinho.',
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Notificar por e-mail'),
                  value: notifyByEmail && _emailValid,
                  onChanged: _emailValid ? (value) => setState(() => notifyByEmail = value) : null,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Notificar por telefone'),
                  subtitle: const Text('SMS. Não é o aviso push do dentista.'),
                  value: notifyByPhone && _phoneValid,
                  onChanged: _phoneValid ? (value) => setState(() => notifyByPhone = value) : null,
                ),
                if (widget.locations.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const AppSectionHeader(
                    title: 'Locais de atendimento',
                    subtitle: 'O paciente pode ficar em mais de um local, ou em nenhum.',
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final location in widget.locations)
                        FilterChip(
                          label: Text(location.active ? location.name : '${location.name} (inativo)'),
                          selected: locationIds.contains(location.id),
                          onSelected: (selected) => setState(() {
                            if (selected) {
                              locationIds.add(location.id);
                            } else {
                              locationIds.remove(location.id);
                            }
                          }),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                CpfField(
                  initial: cpf,
                  onChanged: (value) => setState(() => cpf = value),
                ),
                const SizedBox(height: 20),
                AppSurfaceCard(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Icon(Icons.cake_outlined, color: Theme.of(context).colorScheme.primary),
                    title: const Text('Nascimento'),
                    subtitle: Text(formatDay(birth)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      final picked = await showAppDatePicker(
                        context: context,
                        initialDate: birth,
                        firstDate: DateTime(1920),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setState(() => birth = picked);
                    },
                  ),
                ),
                if (minor) ...[
                  const SizedBox(height: 28),
                  const AppSectionHeader(
                    title: 'Responsável',
                    subtitle: 'Obrigatório para paciente menor de 18 anos.',
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: guardian,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Responsável legal'),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ],
            ),
          ),
          AppFooterBar(
            secondaryLabel: 'Cancelar',
            primaryLabel: 'Salvar',
            onSecondary: () => Navigator.pop(context),
            onPrimary: _save,
            primaryEnabled: _canSave,
          ),
        ],
      ),
    );
  }
}
