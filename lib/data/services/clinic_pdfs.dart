import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../domain/models.dart';
import '../../domain/queries.dart';

Future<Uint8List> buildPatientChartPdf({
  required DentistProfile profile,
  required Patient patient,
  required List<Procedure> history,
}) async {
  final implants = implantsOf(history, patient.id);
  final document = pw.Document();
  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (context) => [
        pw.Text('Prontuário', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 12),
        pw.Text(profile.name),
        pw.Text(profile.cro),
        pw.SizedBox(height: 12),
        pw.Text(patient.name),
        pw.Text(cpfLabel(patient.cpf)),
        pw.Text(patient.phone.isEmpty ? 'Sem telefone' : formatBrazilianPhone(patient.phone)),
        pw.Text('Nascimento ${formatDay(patient.birthDate)}'),
        if (patient.isMinor && patient.guardian.isNotEmpty)
          pw.Text('Responsável legal: ${patient.guardian}'),
        if (patient.notes.isNotEmpty) pw.Text('Observação: ${patient.notes}'),
        pw.SizedBox(height: 16),
        pw.Text('Implantes', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        if (implants.isEmpty) pw.Text('Nenhum pilar registrado.'),
        for (final site in implants)
          pw.Text(
            'Dente ${site.fdi} · ${site.piece?.manufacturer ?? 'Sem fabricante'} ${site.piece?.model ?? ''}',
          ),
        pw.SizedBox(height: 16),
        pw.Text('Histórico', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        for (final procedure in history) ...[
          pw.SizedBox(height: 8),
          pw.Text(
            '${formatDay(procedure.surgeryDate)} · ${procedure.classificationLabel} · ${procedure.teethLabel}',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(procedure.statusLabel),
          if (procedure.sinusLiftLabel != null) pw.Text(procedure.sinusLiftLabel!),
          for (final site in procedure.sites)
            for (final graft in site.grafts) pw.Text(graftTraceLabel(graft)),
          if (procedure.notes.isNotEmpty) pw.Text(procedure.notes),
          for (final visit in procedure.visits)
            pw.Text('${formatDay(visit.date)} · Consulta · ${visit.note}'),
          if (procedure.certificateIssuedAt != null)
            pw.Text('Certificado emitido em ${formatDay(procedure.certificateIssuedAt!)}'),
        ],
      ],
    ),
  );
  return document.save();
}
