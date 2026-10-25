import 'dart:io';

import 'package:flutter/services.dart';

import '../../domain/models.dart';

class WorkOsIdentity {
  const WorkOsIdentity({
    required this.id,
    required this.email,
    required this.name,
    this.accessToken = '',
  });

  final String id;
  final String email;
  final String name;
  final String accessToken;
}

class WorkOsAuthException implements Exception {
  const WorkOsAuthException(this.message);

  final String message;
}

abstract class WorkOsAuth {
  Future<WorkOsIdentity> signIn({required String clientId, required String redirectUri});

  Future<WorkOsIdentity?> currentIdentity({required String clientId});

  Future<void> signOut({required String redirectUri});
}

class NativeWorkOsAuth implements WorkOsAuth {
  static const _channel = MethodChannel('br.com.implateflow/workos');

  @override
  Future<WorkOsIdentity> signIn({required String clientId, required String redirectUri}) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      throw const WorkOsAuthException('O login do WorkOS está disponível no Android e no iOS.');
    }
    try {
      final result = await _channel.invokeMapMethod<String, String>('signIn', {
        'clientId': clientId,
        'redirectUri': redirectUri,
      });
      final id = result?['id'];
      final email = result?['email'];
      final rawName = result?['name'];
      final accessToken = result?['accessToken'] ?? '';
      if (id == null || email == null || id.isEmpty || email.isEmpty || accessToken.isEmpty) {
        throw const WorkOsAuthException('Não foi possível concluir o login.');
      }
      return WorkOsIdentity(
        id: id,
        email: email,
        name: sanitizePersonName(rawName),
        accessToken: accessToken,
      );
    } on PlatformException catch (error) {
      throw WorkOsAuthException(error.message ?? 'Não foi possível concluir o login.');
    }
  }

  @override
  Future<WorkOsIdentity?> currentIdentity({required String clientId}) async {
    if ((!Platform.isAndroid && !Platform.isIOS) || clientId.isEmpty) return null;
    try {
      final result = await _channel.invokeMapMethod<String, String>('currentIdentity', {
        'clientId': clientId,
      });
      final id = result?['id'];
      final email = result?['email'];
      final accessToken = result?['accessToken'] ?? '';
      if (id == null || email == null || id.isEmpty || email.isEmpty || accessToken.isEmpty) {
        return null;
      }
      return WorkOsIdentity(
        id: id,
        email: email,
        name: sanitizePersonName(result?['name']),
        accessToken: accessToken,
      );
    } on PlatformException catch (error) {
      // Falha de rede: mantém sessão local. Sessão inválida volta null (sign-out no restore).
      if (error.code == 'network') {
        throw WorkOsAuthException(error.message ?? 'Sem conexão para renovar a sessão.');
      }
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<void> signOut({required String redirectUri}) async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    try {
      await _channel.invokeMethod<void>('signOut', {
        'redirectUri': redirectUri,
      });
    } on PlatformException catch (error) {
      throw WorkOsAuthException(error.message ?? 'Não foi possível sair.');
    }
  }
}
