import 'package:flutter_test/flutter_test.dart';
import 'package:implate_flow/data/repositories/api_clinic_repository.dart';
import 'package:implate_flow/data/services/clinic_api.dart';
import 'package:implate_flow/domain/clinic_snapshot.dart';
import 'package:implate_flow/domain/models.dart';

class _Server implements ClinicTransport {
  Map<String, dynamic> profile = {
    'name': 'Ana',
    'email': 'a@example.com',
    'phone': '',
    'cro': '',
    'reminderEnabled': false,
    'reminderDaysBefore': 3,
    'emailChannel': false,
    'pushChannel': false,
    'locations': <Map<String, dynamic>>[],
  };
  bool failDefault = true;
  int creates = 0;
  final requests = <String>[];
  Map<String, dynamic>? lastProfileBody;
  @override
  Future<ClinicHttpResponse> send({
    required String method,
    required String path,
    Object? body,
    String? token,
  }) async {
    requests.add('$method $path');
    if (path == '/v1/chart') {
      return ClinicHttpResponse(
        statusCode: 200,
        body: {'profile': profile, 'patients': [], 'procedures': []},
      );
    }
    if (path == '/v1/profile') {
      lastProfileBody = Map<String, dynamic>.from(body as Map);
      profile.addAll(lastProfileBody!);
      return const ClinicHttpResponse(statusCode: 200, body: {});
    }
    if (path == '/v1/locations' && method == 'POST') {
      creates++;
      (profile['locations'] as List).add({
        ...Map<String, dynamic>.from(body as Map),
        'active': true,
        'isDefault': false,
      });
      return const ClinicHttpResponse(statusCode: 201, body: {});
    }
    if (path.endsWith('/default')) {
      if (failDefault) {
        failDefault = false;
        return const ClinicHttpResponse(statusCode: 500, body: {});
      }
      for (final location in profile['locations'] as List) {
        location['isDefault'] = true;
      }
      return const ClinicHttpResponse(statusCode: 200, body: {});
    }
    return const ClinicHttpResponse(statusCode: 200, body: {});
  }
}

void main() {
  test('salvar dados profissionais envia somente um PATCH com os três campos', () async {
    final server = _Server();
    final repository = ApiClinicRepository(
      api: ClinicApi(baseUrl: 'https://api.example', transport: server),
      initial: const ClinicSnapshot(profile: DentistProfile(name: 'Ana', email: 'a@example.com', reminderEnabled: false), signedIn: true, patients: [], procedures: [], sequence: 0),
    );
    repository.signIn(name: 'Ana', email: 'a@example.com', accessToken: 'token');
    await repository.saveProfileIdentity(name: 'Ana Lima', phone: '21999999999', cro: 'RJ 44731');
    expect(server.requests, ['PATCH /v1/profile']);
    expect(server.lastProfileBody, {'name': 'Ana Lima', 'phone': '21999999999', 'cro': 'RJ 44731'});
    expect(repository.current.profile.reminderEnabled, isFalse);
  });
  test(
    'retenta falha parcial sem duplicar clínica nem substituir preferências',
    () async {
      final server = _Server();
      final repository = ApiClinicRepository(
        api: ClinicApi(baseUrl: 'https://api.example', transport: server),
        initial: const ClinicSnapshot(
          profile: DentistProfile(name: 'Ana', email: 'a@example.com'),
          signedIn: true,
          patients: [],
          procedures: [],
          sequence: 0,
        ),
      );
      repository.signIn(
        name: 'Ana',
        email: 'a@example.com',
        accessToken: 'token',
      );
      const profile = DentistProfile(
        name: 'Ana',
        email: 'a@example.com',
        phone: '11999999999',
        cro: 'SP 12345',
        locations: [
          CareLocation(id: 'loc-1', name: 'Clínica', isDefault: true),
        ],
      );
      await expectLater(
        repository.completeFirstSteps(profile),
        throwsA(isA<ClinicApiException>()),
      );
      await repository.completeFirstSteps(profile);
      expect(server.creates, 1);
      expect(server.profile['reminderEnabled'], false);
      expect(server.profile['reminderDaysBefore'], 3);
      expect(repository.current.profile.locations.single.isDefault, true);
    },
  );
}
