import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../domain/certificate.dart';
import '../../domain/models.dart';
import '../core/layout.dart';
import '../view_models.dart';

class CertificateScreen extends StatelessWidget {
  const CertificateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<CertificateViewModel>();
    final procedure = viewModel.procedure;
    final patient = viewModel.patient;
    if (procedure == null || patient == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Certificado')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Procedimento não encontrado.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              TextButton(onPressed: () => context.pop(), child: const Text('Voltar')),
            ],
          ),
        ),
      );
    }
    final missing = missingCertificateFields(
      profile: viewModel.profile,
      patient: patient,
      procedure: procedure,
    );
    if (missing.contains('CRO')) {
      return Scaffold(
        appBar: AppBar(title: const Text('Certificado')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  certificateCroRequiredMessage,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.push('/profile?focus=cro'),
                  child: const Text('Completar cadastro'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final locations = viewModel.careLocations;
    final selected = viewModel.selectedLocation;
    final canIssue = missing.isEmpty && selected != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Certificado')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (missing.isNotEmpty) ...[
            const AppSectionHeader(
              title: 'Rastreio incompleto',
              subtitle: 'Complete os campos para gerar o PDF.',
            ),
            const SizedBox(height: 8),
            AppSurfaceCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final item in missing)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('• $item'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (missing.isEmpty) ...[
            const AppSectionHeader(title: 'Prévia'),
            const SizedBox(height: 8),
            AppSurfaceCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Certificado de procedência',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Text('${viewModel.profile.name}\n${viewModel.profile.cro}'),
                  const SizedBox(height: 12),
                  Text('${patient.name}\nNascimento ${formatDay(patient.birthDate)}'),
                  if (patient.isMinor && patient.guardian.isNotEmpty)
                    Text('Responsável legal: ${patient.guardian}'),
                  if (selected != null) ...[
                    const SizedBox(height: 12),
                    Text(locationAddressLabel(selected)),
                    if (selected.address.trim().isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Endereço do local incompleto. Revise o cadastro do local no perfil.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    '${procedure.classificationLabel}\n'
                    '${formatDay(procedure.surgeryDate)}\n'
                    '${procedure.teethLabel}'
                    '${procedure.sinusLiftLabel == null ? '' : '\n${procedure.sinusLiftLabel}'}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            for (final site in procedure.pillars) ...[
              AppSurfaceCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Dente ${site.fdi}', style: Theme.of(context).textTheme.titleSmall),
                    if (site.piece != null)
                      Text(
                        [
                          if (site.piece!.manufacturer.isNotEmpty || site.piece!.model.isNotEmpty)
                            '${site.piece!.manufacturer} ${site.piece!.model}'.trim(),
                          if (site.piece!.size.isNotEmpty) site.piece!.size,
                          if (site.piece!.manufacturedOn != null)
                            'Fabricação ${formatDay(site.piece!.manufacturedOn!)}',
                          if (site.piece!.expiresOn != null)
                            'Validade ${formatDay(site.piece!.expiresOn!)}',
                        ].join('\n'),
                      ),
                    for (final graft in site.grafts)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '${graftTraceLabel(graft)}'
                          '${graft.expiresOn == null ? '' : '\nValidade ${formatDay(graft.expiresOn!)}'}',
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            const AppSectionHeader(
              title: 'Local de atendimento',
              subtitle: 'Endereço do local em que o paciente foi atendido.',
            ),
            const SizedBox(height: 8),
            if (locations.isEmpty)
              AppSurfaceCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Cadastre um local de atendimento para emitir o certificado.'),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => context.push('/profile'),
                      child: const Text('Gerenciar locais'),
                    ),
                  ],
                ),
              )
            else if (locations.length == 1)
              AppSurfaceCard(
                padding: const EdgeInsets.all(16),
                child: Text(locationAddressLabel(locations.first)),
              )
            else
              AppSurfaceCard(
                padding: const EdgeInsets.all(16),
                child: DropdownButtonFormField<String>(
                  initialValue: viewModel.selectedLocationId ?? selected?.id,
                  decoration: const InputDecoration(labelText: 'Local de atendimento'),
                  items: [
                    for (final location in locations)
                      DropdownMenuItem(
                        value: location.id,
                        child: Text(
                          location.address.trim().isEmpty
                              ? location.name
                              : '${location.name} — ${location.address}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: viewModel.selectLocation,
                ),
              ),
            const SizedBox(height: 12),
            AppSurfaceCard(
              child: SwitchListTile(
                title: const Text('Emitir em 2 vias'),
                subtitle: const Text('Um único PDF com 1ª e 2ª via.'),
                value: viewModel.emitTwoCopies,
                onChanged: viewModel.setEmitTwoCopies,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              procedure.certificateIssuedAt == null
                  ? 'O PDF é gerado no servidor e baixado neste aparelho.'
                  : 'Emitido em ${formatDay(procedure.certificateIssuedAt!)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: !canIssue
                  ? null
                  : () async {
                      final wasIssued = procedure.certificateIssuedAt != null;
                      try {
                        await viewModel.issue();
                      } catch (error) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(error.toString())),
                        );
                        return;
                      }
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            wasIssued
                                ? 'Certificado reemitido com o rastreio atual.'
                                : 'PDF do certificado gerado.',
                          ),
                        ),
                      );
                    },
              child: Text(procedure.certificateIssuedAt == null ? 'Gerar PDF' : 'Reemitir PDF'),
            ),
          ],
        ],
      ),
    );
  }
}
