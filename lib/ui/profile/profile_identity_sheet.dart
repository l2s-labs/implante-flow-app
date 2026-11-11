import 'package:flutter/material.dart';

import '../../data/services/clinic_api.dart';
import '../../domain/certificate.dart';
import '../../domain/first_steps.dart';
import '../../domain/models.dart';
import '../core/app_sheet.dart';
import '../core/cro_field.dart';
import '../core/phone_input_formatter.dart';
import '../view_models.dart';

class ProfileIdentitySheet extends StatefulWidget {
  const ProfileIdentitySheet({
    super.key,
    required this.viewModel,
    this.focusCro = false,
  });
  final ProfileViewModel viewModel;
  final bool focusCro;

  @override
  State<ProfileIdentitySheet> createState() => _ProfileIdentitySheetState();
}

class _ProfileIdentitySheetState extends State<ProfileIdentitySheet> {
  final _form = GlobalKey<FormState>();
  final _croFocus = FocusNode();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _cro;
  late final String _initialName;
  late final String _initialPhone;
  late final String _initialCro;
  bool _saving = false;
  bool _closing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final profile = widget.viewModel.profile;
    _initialName = sanitizePersonName(profile.name);
    _initialPhone = brazilianPhoneDigits(profile.phone);
    _initialCro = normalizeCro(profile.cro) ?? profile.cro.trim();
    _name = TextEditingController(text: _initialName);
    _phone = TextEditingController(text: formatContactPhone(profile.phone));
    _cro = TextEditingController(text: formatCroInput(profile.cro));
    for (final controller in [_name, _phone, _cro]) {
      controller.addListener(_changed);
    }
    if (widget.focusCro) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _croFocus.requestFocus();
      });
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  bool get _dirty =>
      sanitizePersonName(_name.text) != _initialName ||
      brazilianPhoneDigits(_phone.text) != _initialPhone ||
      (normalizeCro(_cro.text) ?? _cro.text.trim()) != _initialCro;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _cro.dispose();
    _croFocus.dispose();
    super.dispose();
  }

  Future<void> _cancel() async {
    if (_saving) return;
    if (_dirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Descartar alterações?'),
          content: const Text('Os dados editados não serão salvos.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Continuar editando'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Descartar'),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }
    _close(false);
  }

  void _close(bool saved) {
    setState(() => _closing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop(saved);
    });
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.viewModel.repository.saveProfileIdentity(
        name: sanitizePersonName(_name.text),
        phone: brazilianPhoneDigits(_phone.text),
        cro: normalizeCro(_cro.text) ?? '',
      );
      if (mounted) _close(true);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ClinicApiException
              ? error.message
              : 'Não foi possível salvar. Tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hintStyle = TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4));
    return PopScope(
      canPop: _closing,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_closing) _cancel();
      },
      child: AppSheet(
        title: 'Editar dados profissionais',
        footer: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _saving ? null : _cancel,
                child: const Text('Cancelar'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: _saving || !_dirty ? null : _save,
                child: Text(_saving ? 'Salvando...' : 'Salvar'),
              ),
            ),
          ],
        ),
        child: Form(
          key: _form,
          child: Column(
            children: [
              TextFormField(
                controller: _name,
                enabled: !_saving,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nome'),
                validator: (value) => sanitizePersonName(value).isEmpty
                    ? 'Informe seu nome.'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phone,
                enabled: !_saving,
                keyboardType: TextInputType.phone,
                inputFormatters: [const ContactPhoneInputFormatter()],
                decoration: InputDecoration(
                  labelText: 'Telefone com DDD',
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  hintText: '(00) 0 0000 0000',
                  hintStyle: hintStyle,
                ),
                validator: (value) =>
                    (value ?? '').trim().isEmpty || firstStepsValidPhone(value!)
                    ? null
                    : 'Informe um telefone válido com DDD.',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _cro,
                focusNode: _croFocus,
                enabled: !_saving,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [const CroInputFormatter()],
                decoration: InputDecoration(
                  labelText: 'CRO',
                  prefixText: 'CRO-',
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  hintText: '00000',
                  hintStyle: hintStyle,
                  helperText: widget.focusCro
                      ? 'Necessário para emitir certificado'
                      : 'Ex.: CRO-RJ 44731',
                ),
                validator: (value) =>
                    (value ?? '').trim().isEmpty || firstStepsValidCro(value!)
                    ? null
                    : 'Informe uma UF válida e o número do CRO.',
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
