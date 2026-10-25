import AuthenticationServices
import Flutter
import Foundation
import Security
import UIKit
import WorkOS

final class WorkOsSignIn: NSObject, ASWebAuthenticationPresentationContextProviding {
  private var session: ASWebAuthenticationSession?
  private var accessToken: String?

  func signIn(clientID: String, redirectURI: String, result: @escaping FlutterResult) {
    let workos = PublicClient(clientID: clientID)
    let authorization: PKCEAuthorizationUrlResult
    do {
      authorization = try workos.getAuthorizationUrlWithPKCE(
        redirectUri: redirectURI,
        provider: "authkit"
      )
      Keychain.delete(key: "refresh_token")
      Keychain.delete(key: "session_id")
      try Keychain.save(key: "code_verifier", value: authorization.codeVerifier)
      try Keychain.save(key: "state", value: authorization.state)
    } catch {
      result(FlutterError(code: "workos", message: "Não foi possível abrir o login.", details: nil))
      return
    }

    guard let scheme = URL(string: redirectURI)?.scheme else {
      result(FlutterError(code: "config", message: "O login do WorkOS não está configurado.", details: nil))
      return
    }

    var loginURL = authorization.url
    if var components = URLComponents(url: authorization.url, resolvingAgainstBaseURL: false) {
      var items = components.queryItems ?? []
      items.append(URLQueryItem(name: "prompt", value: "login"))
      items.append(URLQueryItem(name: "max_age", value: "0"))
      components.queryItems = items
      loginURL = components.url ?? authorization.url
    }

    let session = ASWebAuthenticationSession(
      url: loginURL,
      callbackURLScheme: scheme
    ) { [weak self] url, error in
      self?.session = nil
      if error != nil || url == nil {
        Keychain.delete(key: "code_verifier")
        Keychain.delete(key: "state")
        result(FlutterError(code: "cancelled", message: "Login cancelado.", details: nil))
        return
      }
      self?.exchange(url: url!, clientID: clientID, result: result)
    }
    session.presentationContextProvider = self
    session.prefersEphemeralWebBrowserSession = true
    self.session = session
    if !session.start() {
      result(FlutterError(code: "browser", message: "Não foi possível abrir o login.", details: nil))
    }
  }

  func currentIdentity(clientID: String, result: @escaping FlutterResult) {
    guard let refresh = Keychain.read(key: "refresh_token"), !refresh.isEmpty else {
      result(nil)
      return
    }
    Task {
      do {
        let identity = try await Self.refreshIdentity(clientID: clientID, refreshToken: refresh)
        try Keychain.save(key: "refresh_token", value: identity.refreshToken)
        if let sid = self.sessionId(from: identity.accessToken) {
          try Keychain.save(key: "session_id", value: sid)
        }
        await MainActor.run {
          self.accessToken = identity.accessToken
          result([
            "id": identity.id,
            "email": identity.email,
            "name": identity.name,
            "accessToken": identity.accessToken,
          ])
        }
      } catch let error as URLError {
        await MainActor.run {
          result(FlutterError(code: "network", message: "Sem conexão para renovar a sessão.", details: error.localizedDescription))
        }
      } catch {
        Keychain.delete(key: "refresh_token")
        Keychain.delete(key: "session_id")
        await MainActor.run {
          self.accessToken = nil
          result(nil)
        }
      }
    }
  }

  func signOut(returnTo: String, result: @escaping FlutterResult) {
    session?.cancel()
    session = nil
    let sid = Keychain.read(key: "session_id") ?? sessionId(from: accessToken)
    accessToken = nil
    Keychain.delete(key: "refresh_token")
    Keychain.delete(key: "session_id")
    Keychain.delete(key: "code_verifier")
    Keychain.delete(key: "state")
    guard let sid, !sid.isEmpty, let scheme = URL(string: returnTo)?.scheme else {
      result(nil)
      return
    }
    var components = URLComponents(string: "https://api.workos.com/user_management/sessions/logout")
    components?.queryItems = [
      URLQueryItem(name: "session_id", value: sid),
      URLQueryItem(name: "return_to", value: returnTo),
    ]
    guard let logoutURL = components?.url else {
      result(nil)
      return
    }
    let session = ASWebAuthenticationSession(url: logoutURL, callbackURLScheme: scheme) { [weak self] _, _ in
      self?.session = nil
      result(nil)
    }
    session.presentationContextProvider = self
    session.prefersEphemeralWebBrowserSession = false
    self.session = session
    if !session.start() {
      result(nil)
    }
  }

  func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
    let window = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
      .first { $0.isKeyWindow }
    return window ?? ASPresentationAnchor()
  }

  private func exchange(url: URL, clientID: String, result: @escaping FlutterResult) {
    let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
    let code = items.first { $0.name == "code" }?.value
    let state = items.first { $0.name == "state" }?.value
    let expected = Keychain.read(key: "state")
    let verifier = Keychain.read(key: "code_verifier")
    Keychain.delete(key: "code_verifier")
    Keychain.delete(key: "state")
    guard let code, let verifier, let state, state == expected else {
      result(FlutterError(code: "state", message: "Não foi possível confirmar o login.", details: nil))
      return
    }
    Task {
      do {
        let authentication = try await PublicClient(clientID: clientID).authenticateWithCode(
          code: code,
          codeVerifier: verifier
        )
        try Keychain.save(key: "refresh_token", value: authentication.refreshToken)
        let token = authentication.accessToken
        if let sid = self.sessionId(from: token) {
          try Keychain.save(key: "session_id", value: sid)
        }
        let user = authentication.user
        await MainActor.run {
          self.accessToken = token
          result([
            "id": user.id,
            "email": user.email,
            "name": Self.registeredName(
              name: user.name,
              firstName: user.firstName,
              lastName: user.lastName,
              email: user.email
            ),
            "accessToken": token,
          ])
        }
      } catch {
        await MainActor.run {
          result(FlutterError(code: "exchange", message: "Não foi possível concluir o login.", details: nil))
        }
      }
    }
  }

  private static func registeredName(
    name: String?,
    firstName: String?,
    lastName: String?,
    email: String
  ) -> String {
    if let name = name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
      return name
    }
    let combined = [firstName, lastName]
      .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
      .joined(separator: " ")
    return combined.isEmpty ? email : combined
  }

  private static func refreshIdentity(clientID: String, refreshToken: String) async throws -> RefreshedIdentity {
    var request = URLRequest(url: URL(string: "https://api.workos.com/user_management/authenticate")!)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONSerialization.data(withJSONObject: [
      "client_id": clientID,
      "grant_type": "refresh_token",
      "refresh_token": refreshToken,
    ])
    let (data, response) = try await URLSession.shared.data(for: request)
    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
      let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      let user = json["user"] as? [String: Any],
      let id = user["id"] as? String, !id.isEmpty,
      let email = user["email"] as? String, !email.isEmpty,
      let nextRefresh = json["refresh_token"] as? String, !nextRefresh.isEmpty,
      let access = json["access_token"] as? String, !access.isEmpty
    else {
      throw KeychainError()
    }
    return RefreshedIdentity(
      id: id,
      email: email,
      name: registeredName(
        name: user["name"] as? String,
        firstName: user["first_name"] as? String,
        lastName: user["last_name"] as? String,
        email: email
      ),
      refreshToken: nextRefresh,
      accessToken: access
    )
  }

  private func sessionId(from accessToken: String?) -> String? {
    guard let accessToken else { return nil }
    let parts = accessToken.split(separator: ".")
    guard parts.count >= 2 else { return nil }
    var payload = String(parts[1])
      .replacingOccurrences(of: "-", with: "+")
      .replacingOccurrences(of: "_", with: "/")
    let remainder = payload.count % 4
    if remainder > 0 {
      payload += String(repeating: "=", count: 4 - remainder)
    }
    guard let data = Data(base64Encoded: payload),
      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else { return nil }
    return json["sid"] as? String
  }
}

private enum Keychain {
  static func save(key: String, value: String) throws {
    let data = Data(value.utf8)
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: "br.com.implateflow.workos",
      kSecAttrAccount as String: key,
    ]
    SecItemDelete(query as CFDictionary)
    var insert = query
    insert[kSecValueData as String] = data
    insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    let status = SecItemAdd(insert as CFDictionary, nil)
    guard status == errSecSuccess else {
      throw KeychainError()
    }
  }

  static func read(key: String) -> String? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: "br.com.implateflow.workos",
      kSecAttrAccount as String: key,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var item: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
      let data = item as? Data
    else { return nil }
    return String(data: data, encoding: .utf8)
  }

  static func delete(key: String) {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: "br.com.implateflow.workos",
      kSecAttrAccount as String: key,
    ]
    SecItemDelete(query as CFDictionary)
  }
}

private struct KeychainError: Error {}

private struct RefreshedIdentity {
  let id: String
  let email: String
  let name: String
  let refreshToken: String
  let accessToken: String
}
