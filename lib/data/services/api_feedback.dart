/// Feedback tipado a partir do resultado real da API (nunca sucesso antecipado).
enum ApiFeedbackKind { success, error, pending }

class ApiFeedback {
  const ApiFeedback({required this.kind, required this.message});

  final ApiFeedbackKind kind;
  final String message;

  factory ApiFeedback.success(String message) =>
      ApiFeedback(kind: ApiFeedbackKind.success, message: message);

  factory ApiFeedback.error(String message) =>
      ApiFeedback(kind: ApiFeedbackKind.error, message: message);

  factory ApiFeedback.pending([String message = 'Solicitação recebida. Processamento em andamento.']) =>
      ApiFeedback(kind: ApiFeedbackKind.pending, message: message);
}

/// Converte status HTTP + corpo opcional em mensagem amigável (pt-BR).
String friendlyApiMessage(int statusCode, {Object? body, String? action}) {
  final fromBody = _safeBodyMessage(body);
  if (statusCode == 202) {
    return 'Solicitação recebida. Processamento em andamento.';
  }
  if (statusCode >= 200 && statusCode < 300) {
    return action == null || action.isEmpty ? 'Operação concluída com sucesso.' : action;
  }
  if (fromBody != null) return fromBody;
  return switch (statusCode) {
    0 => 'Sem conexão com a API. Verifique a rede e tente de novo.',
    400 || 422 => 'Revise os dados informados e tente de novo.',
    401 => 'Sessão expirada. Entre de novo para continuar.',
    403 => 'Você não tem permissão para esta ação.',
    404 => 'Registro não encontrado. Atualize a tela e tente de novo.',
    409 => 'Os dados mudaram. Recarregue e revise antes de salvar.',
    429 => 'Muitas tentativas. Aguarde um momento e tente de novo.',
    >= 500 => 'Serviço indisponível no momento. Tente de novo em instantes.',
    _ => 'Não foi possível concluir a operação.',
  };
}

String? _safeBodyMessage(Object? body) {
  if (body is! Map) return null;
  // Contrato: { "error": { "code", "message", "requestId" } }
  // Legado flat: { "error": "code", "message": "..." }
  final error = body['error'];
  if (error is Map) {
    final message = error['message'];
    if (message is String) {
      final trimmed = message.trim();
      if (_isSafeUserMessage(trimmed)) return trimmed;
    }
    final code = error['code'];
    if (code is String) return _defaultMessageForErrorCode(code);
    return null;
  }
  if (error is String) {
    final topLevel = body['message'];
    if (topLevel is String) {
      final trimmed = topLevel.trim();
      if (_isSafeUserMessage(trimmed)) return trimmed;
    }
    return _defaultMessageForErrorCode(error);
  }
  return null;
}

bool _isSafeUserMessage(String trimmed) {
  if (trimmed.isEmpty) return false;
  final lower = trimmed.toLowerCase();
  if (lower.contains('stack') || lower.contains('exception') || lower.contains('sql')) {
    return false;
  }
  return trimmed.length <= 180;
}

String? _defaultMessageForErrorCode(String code) => switch (code) {
      'cep_invalid' => 'CEP inválido. Informe 8 dígitos.',
      'cep_not_found' => 'CEP não encontrado.',
      'viacep_unavailable' || 'upstream_unavailable' =>
        'Consulta de CEP indisponível no momento. Tente de novo.',
      _ => null,
    };

/// Código estruturado: `error.code` (contrato) ou `error` string (legado).
String? apiErrorCode(Object? body) {
  if (body is! Map) return null;
  final error = body['error'];
  if (error is Map) {
    final code = error['code'];
    return code is String ? code : null;
  }
  return error is String ? error : null;
}
