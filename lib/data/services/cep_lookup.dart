/// Resposta 200 do `GET /v1/ceps/:cep` — campos PT: logradouro/bairro/localidade/uf.
class CepAddress {
  const CepAddress({
    required this.cep,
    required this.street,
    required this.neighborhood,
    required this.city,
    required this.state,
    this.source,
  });

  final String cep;
  final String street;
  final String neighborhood;
  final String city;
  final String state;
  final String? source;

  factory CepAddress.fromJson(Map<String, dynamic> json) {
    String digits(String? value) => (value ?? '').replaceAll(RegExp(r'\D'), '');
    return CepAddress(
      cep: digits(json['cep'] as String?),
      street: (json['logradouro'] as String? ?? json['street'] as String? ?? '').trim(),
      neighborhood: (json['bairro'] as String? ?? json['neighborhood'] as String? ?? '').trim(),
      city: (json['localidade'] as String? ?? json['city'] as String? ?? '').trim(),
      state: (json['uf'] as String? ?? json['state'] as String? ?? '').trim().toUpperCase(),
      source: json['source'] as String?,
    );
  }
}

String cepErrorMessage({required int statusCode, String? code, required String fallback}) {
  return switch (code) {
    'cep_invalid' => 'CEP inválido. Informe 8 dígitos.',
    'cep_not_found' => 'CEP não encontrado.',
    'viacep_unavailable' || 'upstream_unavailable' =>
      'Consulta de CEP indisponível no momento. Tente de novo.',
    _ => fallback.isNotEmpty
        ? fallback
        : switch (statusCode) {
            400 => 'CEP inválido. Informe 8 dígitos.',
            404 => 'CEP não encontrado.',
            502 => 'Consulta de CEP indisponível no momento. Tente de novo.',
            _ => 'Não foi possível consultar o CEP.',
          },
  };
}
