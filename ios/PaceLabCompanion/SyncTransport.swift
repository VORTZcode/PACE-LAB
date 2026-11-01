import Foundation
import Security

struct HeartRatePoint: Codable {
    let timestamp: String
    let bpm: Double
}

struct WorkoutPayload: Codable {
    let source_uuid: String
    let activity_type: Int
    let activity_kind: String
    let started_at: String
    let ended_at: String
    let duration_seconds: Double
    let distance_meters: Double?
    let active_energy_kcal: Double?
    let hr_average_bpm: Double?
    let hr_max_bpm: Double?
    let hr_at_end_bpm: Double?
    let recovery_hr_1min: Double?
    let recovery_hr_2min: Double?
    let recovery_hr_3min: Double?
    let recovery_hr_5min: Double?
    let apple_recovery_1min_delta: Double?
    let recovery_state: String
    let heart_rate_series: [HeartRatePoint]
}

struct AuthSession: Codable {
    let access_token: String
    let refresh_token: String
    let expires_at: TimeInterval
}

struct AuthResponse: Decodable {
    let access_token: String
    let refresh_token: String
    let expires_in: Int
}

enum SyncFailure: Error {
    case missingConfiguration, invalidServer, expiredSession, rejected(Int), invalidResponse
}

// Only URL and public key are in UserDefaults. Session credentials are in iOS Keychain.
final class SyncTransport {
    static let shared = SyncTransport()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let sessionKey = "pace_lab_healthkit_session_v1"
    private var root: URL? {
        guard let value = UserDefaults.standard.string(forKey: "pace_sync_url"),
              let url = URL(string: value), url.scheme == "https", url.path.isEmpty || url.path == "/",
              url.host?.hasSuffix(".supabase.co") == true else { return nil }
        return url
    }
    private var publicKey: String? {
        UserDefaults.standard.string(forKey: "pace_sync_key")
    }
    private func endpoint(_ path: String) throws -> URL {
        guard let root = root, let full = URL(string: path, relativeTo: root)?.absoluteURL else { throw SyncFailure.missingConfiguration }
        return full
    }
    func configure(url: String, publicKey: String) throws {
        guard let candidate = URL(string: url), candidate.scheme == "https", candidate.host?.hasSuffix(".supabase.co") == true, (candidate.path.isEmpty || candidate.path == "/") else { throw SyncFailure.invalidServer }
        UserDefaults.standard.set(candidate.absoluteString, forKey: "pace_sync_url")
        UserDefaults.standard.set(publicKey, forKey: "pace_sync_key")
    }
    private func readSession() -> AuthSession? {
        guard let blob = Keychain.read(sessionKey) else { return nil }
        return try? decoder.decode(AuthSession.self, from: blob)
    }
    private func saveSession(_ session: AuthSession) {
        guard let blob = try? encoder.encode(session) else { return }
        Keychain.write(sessionKey, value: blob)
    }
    private func tokenRequest(path: String, body: [String: String]) async throws -> AuthResponse {
        guard let key = publicKey else { throw SyncFailure.missingConfiguration }
        var request = URLRequest(url: try endpoint(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "apikey")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SyncFailure.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw SyncFailure.rejected(http.statusCode) }
        return try decoder.decode(AuthResponse.self, from: data)
    }
    func signIn(email: String, password: String) async throws {
        let auth = try await tokenRequest(path: "auth/v1/token?grant_type=password", body: ["email":email, "password":password])
        saveSession(AuthSession(access_token: auth.access_token, refresh_token: auth.refresh_token, expires_at: Date().timeIntervalSince1970 + Double(auth.expires_in)))
    }
    private func validAccessToken() async throws -> String {
        guard let session = readSession() else { throw SyncFailure.expiredSession }
        if session.expires_at > Date().timeIntervalSince1970 + 90 { return session.access_token }
        let auth = try await tokenRequest(path: "auth/v1/token?grant_type=refresh_token", body: ["refresh_token":session.refresh_token])
        let next = AuthSession(access_token: auth.access_token, refresh_token: auth.refresh_token, expires_at: Date().timeIntervalSince1970 + Double(auth.expires_in))
        saveSession(next)
        return next.access_token
    }
    func upsert(_ payload: WorkoutPayload) async throws {
        guard let key = publicKey else { throw SyncFailure.missingConfiguration }
        let token = try await validAccessToken()
        var req = URLRequest(url: try endpoint("rest/v1/health_workouts?on_conflict=user_id,source_uuid"))
        req.httpMethod = "POST"
        req.setValue(key, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("resolution=merge-duplicates,return=minimal", forHTTPHeaderField: "Prefer")
        req.httpBody = try encoder.encode([payload])
        let (_, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw SyncFailure.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw SyncFailure.rejected(http.statusCode) }
    }
}

enum Keychain {
    static func write(_ key: String, value: Data) {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: key]
        SecItemDelete(query as CFDictionary)
        var data = query
        data[kSecValueData as String] = value
        data[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(data as CFDictionary, nil)
    }
    static func read(_ key: String) -> Data? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: key,
                                    kSecReturnData as String: true,
                                    kSecMatchLimit as String: kSecMatchLimitOne]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }
}
