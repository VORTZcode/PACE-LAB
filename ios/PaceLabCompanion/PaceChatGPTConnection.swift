import Foundation
import SwiftUI
import CryptoKit
import Network
import Security
import SafariServices

// OpenAI Sign in with ChatGPT for a local open-source personal application.
// Tokens remain in iOS Keychain, never in the repository, logs, webviews or app URLs.
enum PaceChatError: LocalizedError {
    case invalid(String)
    var errorDescription: String? {
        switch self { case .invalid(let value): return value }
    }
}

private enum PaceCredentialVault {
    static let service = "com.pacelab.healthcompanion.chatgpt"
    static func save(_ data: Data, name: String) throws {
        let key: [String: Any] = [kSecClass as String:kSecClassGenericPassword,
                                  kSecAttrService as String: service,
                                  kSecAttrAccount as String: name]
        let attributes: [String:Any] = [kSecValueData as String:data]
        let update = SecItemUpdate(key as CFDictionary,attributes as CFDictionary)
        if update == errSecSuccess { return }
        guard update == errSecItemNotFound else {
            throw PaceChatError.invalid("Mise à jour du trousseau impossible (\(update)).")
        }
        var query = key
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(query as CFDictionary,nil)
        guard status == errSecSuccess else {
            throw PaceChatError.invalid("Stockage sécurisé impossible (\(status)).")
        }
    }
    static func load(name: String) -> Data? {
        let query: [String:Any] = [kSecClass as String:kSecClassGenericPassword,
                                  kSecAttrService as String:service,
                                  kSecAttrAccount as String:name,
                                  kSecReturnData as String:true,
                                  kSecMatchLimit as String:kSecMatchLimitOne]
        var output: CFTypeRef?
        return SecItemCopyMatching(query as CFDictionary, &output) == errSecSuccess ? (output as? Data) : nil
    }
    static func erase(name: String) {
        SecItemDelete([kSecClass as String:kSecClassGenericPassword,
                       kSecAttrService as String:service,
                       kSecAttrAccount as String:name] as CFDictionary)
    }
}

private struct PaceChatSession: Codable {
    var clientID: String
    var subject: String
    var email: String
    var idToken: String
    var accessToken: String
    var refreshToken: String
    var scopes: [String]
    var expiresAt: Date
    var allowsPlan: Bool { scopes.contains("chatgpt.tokens.use.direct") }
}

struct PaceChatWebPage: Identifiable {
    let id = UUID()
    let url: URL
}

struct PaceChatBrowser: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.preferredControlTintColor = .systemTeal
        return controller
    }
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

private final class PaceCompletionGate: @unchecked Sendable {
    private let lock = NSLock()
    private var used = false
    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !used else { return false }
        used = true
        return true
    }
}

// HTTP loopback OAuth callback only on 127.0.0.1; no shared web backend or client secret.
private final class PaceLocalCallback {
    let state: String
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "pace.chatgpt.oauth.loopback")
    private let handler: @Sendable ([String:String]) -> Void
    var port: UInt16 { listener?.port?.rawValue ?? 0 }

    init(state: String, handler: @escaping @Sendable ([String:String]) -> Void) throws {
        self.state = state
        self.handler = handler
        let parameters = NWParameters.tcp
        guard let localIP = IPv4Address("127.0.0.1") else {
            throw PaceChatError.invalid("Adresse locale indisponible.")
        }
        parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(localIP), port: .any)
        listener = try NWListener(using: parameters)
    }
    func start() async throws -> UInt16 {
        guard let listener else { throw PaceChatError.invalid("Écoute locale impossible.") }
        listener.newConnectionLimit = 1
        listener.newConnectionHandler = { [weak self] connection in self?.handle(connection) }
        return try await withCheckedThrowingContinuation { continuation in
            let gate = PaceCompletionGate()
            listener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    guard gate.claim() else { return }
                    continuation.resume(returning: listener.port?.rawValue ?? 0)
                case .failed(let error):
                    guard gate.claim() else { return }
                    continuation.resume(throwing: error)
                default: break
                }
            }
            listener.start(queue: queue)
        }
    }
    func stop() { listener?.cancel(); listener = nil }

    private func handle(_ connection: NWConnection) {
        guard case .hostPort(let host, _) = connection.endpoint,
              case .ipv4(let address) = host,
              address.debugDescription == "127.0.0.1" else {
            connection.cancel(); return
        }
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data,_,_,_ in
            guard let self, let data, let line = String(data:data,encoding:.utf8)?.components(separatedBy:"\r\n").first,
                  line.hasPrefix("GET /auth/callback?"),
                  let path = line.split(separator:" ").dropFirst().first,
                  let uri = URLComponents(string:"http://127.0.0.1" + path),
                  let components = uri.queryItems else {
                connection.cancel(); return
            }
            let params = Dictionary(components.compactMap { item -> (String,String)? in
                guard let value = item.value else { return nil }
                return (item.name,value)
            }, uniquingKeysWith: { a,_ in a })
            guard params["state"] == self.state else { connection.cancel(); return }
            let html = "<html><head><meta name='viewport' content='width=device-width, initial-scale=1'></head><body style='font-family:-apple-system;text-align:center;padding:3em'><h2>PACE LAB</h2><p>Authentification reçue. Revenez à l’application.</p></body></html>"
            let response = "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: \(html.utf8.count)\r\nConnection: close\r\nCache-Control: no-store\r\n\r\n\(html)"
            connection.send(content:response.data(using:.utf8),completion:.contentProcessed { _ in connection.cancel() })
            self.handler(params)
        }
    }
}

private enum PaceOIDCVerify {
    static func b64(_ value: String) -> Data? {
        var s = value.replacingOccurrences(of:"-",with:"+").replacingOccurrences(of:"_",with:"/")
        s += String(repeating:"=",count:(4-s.count%4)%4)
        return Data(base64Encoded:s)
    }
    private static func derLength(_ count: Int) -> Data {
        if count < 128 { return Data([UInt8(count)]) }
        if count < 256 { return Data([0x81,UInt8(count)]) }
        return Data([0x82,UInt8((count>>8)&255),UInt8(count&255)])
    }
    private static func integer(_ bytes: Data) -> Data {
        var data = bytes
        if data.first.map({ ($0 & 0x80) != 0 }) == true { data.insert(0,at:0) }
        return Data([0x02]) + derLength(data.count) + data
    }
    static func verify(_ token: String, clientID: String, nonce: String) async throws -> (String,String) {
        let parts = token.split(separator:".").map(String.init)
        guard parts.count == 3,
              let headerData = b64(parts[0]),
              let head = try JSONSerialization.jsonObject(with:headerData) as? [String:Any],
              let kid = head["kid"] as? String, head["alg"] as? String == "RS256",
              let signature = b64(parts[2]),
              let bodyData = b64(parts[1]),
              let claims = try JSONSerialization.jsonObject(with:bodyData) as? [String:Any] else {
            throw PaceChatError.invalid("Jeton d'identité non reconnu.")
        }
        var request = URLRequest(url: URL(string:"https://auth.openai.com/.well-known/jwks.json")!)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (bytes, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let jwks = try JSONSerialization.jsonObject(with:bytes) as? [String:Any],
              let keys = jwks["keys"] as? [[String:Any]],
              let key = keys.first(where:{ $0["kid"] as? String == kid && $0["kty"] as? String == "RSA" }),
              let n = key["n"] as? String, let e = key["e"] as? String,
              let modulus = b64(n), let exponent = b64(e) else {
            throw PaceChatError.invalid("Signature ChatGPT : clé publique introuvable.")
        }
        let partsOfKey = integer(modulus) + integer(exponent)
        let publicKeyData = Data([0x30]) + derLength(partsOfKey.count) + partsOfKey
        guard let publicKey = SecKeyCreateWithData(publicKeyData as CFData,
            [kSecAttrKeyType as String:kSecAttrKeyTypeRSA,
             kSecAttrKeyClass as String:kSecAttrKeyClassPublic,
             kSecAttrKeySizeInBits as String:modulus.count*8] as CFDictionary,nil),
              SecKeyVerifySignature(publicKey,.rsaSignatureMessagePKCS1v15SHA256,
                    Data("\(parts[0]).\(parts[1])".utf8) as CFData,
                    signature as CFData,nil) else {
            throw PaceChatError.invalid("Échec de vérification de l'identité ChatGPT.")
        }
        let aud: Bool = (claims["aud"] as? String) == clientID ||
            ((claims["aud"] as? [String])?.contains(clientID) == true)
        guard claims["iss"] as? String == "https://auth.openai.com",
              aud,
              claims["nonce"] as? String == nonce,
              let exp = claims["exp"] as? Double, exp > Date.now.timeIntervalSince1970,
              let sub = claims["sub"] as? String, !sub.isEmpty else {
            throw PaceChatError.invalid("Identité expirée ou non liée à cette application.")
        }
        return (sub, claims["email"] as? String ?? "Compte ChatGPT")
    }
}

@MainActor final class PaceChatGPTConnection: ObservableObject {
    @Published private(set) var isConnected = false
    @Published private(set) var planUsageEnabled = false
    @Published private(set) var email = ""
    @Published private(set) var status = "ChatGPT non connecté"
    @Published var isBusy = false
    @Published var browser: PaceChatWebPage?
    @Published private(set) var models: [(name:String,slug:String)] = []
    @Published var selectedModel = UserDefaults.standard.string(forKey:"pace.coach.model") ?? "" {
        didSet {
            if !selectedModel.isEmpty { UserDefaults.standard.set(selectedModel,forKey:"pace.coach.model") }
        }
    }

    private var credentials: PaceChatSession?
    private var loopback: PaceLocalCallback?
    private var pending: (state:String,nonce:String,verifier:String,redirect:String,oldID:String?)?
    private let hostID: String

    init() {
        let defaults = UserDefaults.standard
        if let value = defaults.string(forKey:"pace.chatgpt.host-id") { hostID = value }
        else {
            let value = "urn:uuid:" + UUID().uuidString.lowercased()
            defaults.set(value,forKey:"pace.chatgpt.host-id")
            hostID = value
        }
        if let data = PaceCredentialVault.load(name:"session"),
           let stored = try? JSONDecoder().decode(PaceChatSession.self,from:data) {
            credentials = stored
            isConnected = true
            planUsageEnabled = stored.allowsPlan
            email = stored.email
            status = stored.allowsPlan ? "Compte lié · abonnement autorisé" : "Compte lié · accès IA non autorisé"
            Task { try? await self.discoverModels() }
        }
    }

    func signIn() {
        guard !isBusy else { return }
        isBusy = true
        status = "Ouverture de la connexion sécurisée…"
        Task { [weak self] in
            guard let self else { return }
            do {
                let state = UUID().uuidString.replacingOccurrences(of:"-",with:"")
                let nonce = UUID().uuidString.replacingOccurrences(of:"-",with:"")
                let verifier = (UUID().uuidString+UUID().uuidString+UUID().uuidString).replacingOccurrences(of:"-",with:"")
                let callback = try PaceLocalCallback(state:state) { [weak self] params in
                    Task { [weak self] in await self?.complete(params) }
                }
                let port = try await callback.start()
                guard port != 0 else { throw PaceChatError.invalid("Port OAuth indisponible.") }
                loopback = callback
                let redirect = "http://127.0.0.1:\(port)/auth/callback"
                let challenge = Data(SHA256.hash(data:Data(verifier.utf8)))
                    .base64URLEncodedString()
                let currentID = credentials?.clientID
                pending = (state,nonce,verifier,redirect,currentID)
                var url = URLComponents(string:"https://auth.openai.com/api/accounts/authorize")!
                var items: [URLQueryItem] = [
                    .init(name:"client_id",value:currentID ?? "dynamic_agent_client"),
                    .init(name:"ext_agent_host_id",value:hostID),
                    .init(name:"response_type",value:"code"),
                    .init(name:"redirect_uri",value:redirect),
                    .init(name:"scope",value:"openid profile email offline_access resource.invoke chatgpt.tokens.use.direct"),
                    .init(name:"resource",value:"https://api.openai.com/v1"),
                    .init(name:"state",value:state),
                    .init(name:"nonce",value:nonce),
                    .init(name:"code_challenge_method",value:"S256"),
                    .init(name:"code_challenge",value:challenge)
                ]
                if currentID == nil { items.append(.init(name:"agent_name_hint",value:"PACE LAB")) }
                else if let hint = credentials?.idToken { items.append(.init(name:"id_token_hint",value:hint)) }
                url.queryItems = items
                guard let authorizationURL = url.url else { throw PaceChatError.invalid("URL d’autorisation impossible.") }
                browser = PaceChatWebPage(url:authorizationURL)
                status = "Autorise PACE LAB dans ChatGPT"
            } catch {
                fail(error.localizedDescription)
            }
        }
    }

    private func complete(_ params:[String:String]) async {
        guard let request = pending, params["state"] == request.state else { return }
        browser = nil
        if let error = params["error"] { fail("Connexion refusée : \(error)"); return }
        guard let code = params["code"], !code.isEmpty else { fail("Code d’accès manquant."); return }
        guard let issued = params["client_id"] ?? request.oldID,
              !issued.isEmpty && issued != "dynamic_agent_client",
              (request.oldID == nil || request.oldID == issued) else {
            fail("Enregistrement du client ChatGPT non confirmé."); return
        }
        do {
            let tokens = try await tokenRequest([
                "grant_type":"authorization_code", "client_id":issued,
                "code":code,"code_verifier":request.verifier,
                "redirect_uri":request.redirect,"resource":"https://api.openai.com/v1"
            ])
            guard let idToken = tokens["id_token"] as? String,
                  let access = tokens["access_token"] as? String,
                  let refresh = tokens["refresh_token"] as? String else {
                throw PaceChatError.invalid("ChatGPT n’a pas fourni les identifiants attendus.")
            }
            let verified = try await PaceOIDCVerify.verify(idToken,clientID:issued,nonce:request.nonce)
            if let previous = credentials, request.oldID != nil && previous.subject != verified.0 {
                throw PaceChatError.invalid("Le compte connecté ne correspond pas au compte initial.")
            }
            let scopes = (tokens["scope"] as? String ?? "").split(separator:" ").map(String.init)
            let session = PaceChatSession(clientID:issued,subject:verified.0,email:verified.1,
                idToken:idToken,accessToken:access,refreshToken:refresh,scopes:scopes,
                expiresAt:Date.now.addingTimeInterval(tokens["expires_in"] as? Double ?? 3600))
            try PaceCredentialVault.save(try JSONEncoder().encode(session),name:"session")
            credentials = session
            email = session.email
            isConnected = true
            planUsageEnabled = session.allowsPlan
            status = session.allowsPlan ? "Abonnement ChatGPT autorisé" : "Connecté sans autorisation d’utiliser l’abonnement"
            isBusy = false
            loopback?.stop(); loopback = nil; pending = nil
            if session.allowsPlan { try await discoverModels() }
        } catch {
            fail(error.localizedDescription)
        }
    }

    private func tokenRequest(_ fields:[String:String]) async throws -> [String:Any] {
        var url = URLRequest(url:URL(string:"https://auth.openai.com/api/accounts/oauth/token")!)
        url.httpMethod = "POST"
        url.setValue("application/x-www-form-urlencoded",forHTTPHeaderField:"Content-Type")
        let form = URLComponents()
        var components = form
        components.queryItems = fields.sorted(by:{$0.key < $1.key}).map { .init(name:$0.key,value:$0.value) }
        url.httpBody = components.percentEncodedQuery?.data(using:.utf8)
        let (data,response) = try await URLSession.shared.data(for:url)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let parsed = try JSONSerialization.jsonObject(with:data) as? [String:Any] else {
            throw PaceChatError.invalid("Échange OAuth impossible. Réessaie la connexion.")
        }
        return parsed
    }

    private func refreshIfRequired() async throws {
        guard let current = credentials else { throw PaceChatError.invalid("Connecte ton compte ChatGPT.") }
        guard current.expiresAt.timeIntervalSinceNow < 120 else { return }
        let tokens = try await tokenRequest([
            "grant_type":"refresh_token","client_id":current.clientID,
            "refresh_token":current.refreshToken,"resource":"https://api.openai.com/v1"
        ])
        guard let access = tokens["access_token"] as? String else {
            throw PaceChatError.invalid("Session ChatGPT expirée. Reconnecte le compte.")
        }
        var updated = current
        updated.accessToken = access
        updated.refreshToken = tokens["refresh_token"] as? String ?? current.refreshToken
        updated.expiresAt = .now.addingTimeInterval(tokens["expires_in"] as? Double ?? 3600)
        if let scopes = tokens["scope"] as? String { updated.scopes = scopes.split(separator:" ").map(String.init) }
        try PaceCredentialVault.save(try JSONEncoder().encode(updated),name:"session")
        credentials = updated
        planUsageEnabled = updated.allowsPlan
    }

    func discoverModels() async throws {
        guard planUsageEnabled else { return }
        try await refreshIfRequired()
        guard let token = credentials?.accessToken else { return }
        var request = URLRequest(url:URL(string:"https://api.openai.com/v1/models")!)
        request.setValue("Bearer \(token)",forHTTPHeaderField:"Authorization")
        let (data,response) = try await URLSession.shared.data(for:request)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try JSONSerialization.jsonObject(with:data) as? [String:Any],
              let available = json["models"] as? [[String:Any]] else {
            throw PaceChatError.invalid("Liste des modèles ChatGPT indisponible.")
        }
        models = available.compactMap { entry in
            guard let slug = entry["slug"] as? String,
                  entry["visibility"] as? String == "list" else { return nil }
            return (name:entry["display_name"] as? String ?? slug,slug:slug)
        }
        if !models.contains(where:{$0.slug == selectedModel}) {
            selectedModel = models.first(where:{$0.slug == "gpt-6.1-sol"})?.slug
                ?? models.first?.slug ?? ""
        }
    }

    func answer(instructions:String, input:String, onDelta:((String)->Void)? = nil) async throws -> String {
        guard planUsageEnabled else { throw PaceChatError.invalid("Active l’utilisation de ton abonnement ChatGPT.") }
        try await refreshIfRequired()
        if selectedModel.isEmpty { try await discoverModels() }
        guard let token = credentials?.accessToken, !selectedModel.isEmpty else {
            throw PaceChatError.invalid("Aucun modèle disponible pour ce compte.")
        }
        var request = URLRequest(url:URL(string:"https://api.openai.com/v1/responses")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)",forHTTPHeaderField:"Authorization")
        request.setValue("application/json",forHTTPHeaderField:"Content-Type")
        request.timeoutInterval = 120
        request.httpBody = try JSONSerialization.data(withJSONObject:[
            "model":selectedModel,"store":false,"stream":true,
            "instructions":instructions,
            "input":[["role":"user","content":input]]
        ])
        let (stream,response) = try await URLSession.shared.bytes(for:request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw PaceChatError.invalid("Requête ChatGPT refusée (\((response as? HTTPURLResponse)?.statusCode ?? 0)). Vérifie ton compte ou tes limites.")
        }
        var output = ""
        var completed = false
        for try await line in stream.lines {
            if Task.isCancelled { throw CancellationError() }
            guard line.hasPrefix("data: ") else { continue }
            let payload = String(line.dropFirst(6))
            if payload == "[DONE]" { continue }
            guard let data = payload.data(using:.utf8),
                  let event = try? JSONSerialization.jsonObject(with:data) as? [String:Any],
                  let kind = event["type"] as? String else { continue }
            switch kind {
            case "response.output_text.delta":
                if let fragment = event["delta"] as? String {
                    output += fragment
                    onDelta?(fragment)
                }
            case "response.completed": completed = true
            case "response.failed":
                let message = (event["response"] as? [String:Any])?["error"] as? [String:Any]
                throw PaceChatError.invalid(message?["code"] as? String ?? "ChatGPT n’a pas terminé sa réponse.")
            case "response.incomplete":
                throw PaceChatError.invalid("Réponse ChatGPT incomplète.")
            default: break
            }
            if output.count > 30000 { throw PaceChatError.invalid("Réponse trop volumineuse.") }
        }
        guard completed else { throw PaceChatError.invalid("La réponse ChatGPT s’est interrompue.") }
        return output.trimmingCharacters(in:.whitespacesAndNewlines)
    }

    func cancelPendingSignIn() {
        browser = nil
        loopback?.stop(); loopback = nil; pending = nil
        isBusy = false
        status = isConnected ? "Compte ChatGPT déjà connecté" : "Connexion annulée."
    }

    func disconnect() {
        let former = credentials
        browser = nil; loopback?.stop(); loopback = nil; pending = nil
        PaceCredentialVault.erase(name:"session")
        credentials = nil
        isBusy = false; isConnected = false; planUsageEnabled = false; email = ""
        models = []; selectedModel = ""
        UserDefaults.standard.removeObject(forKey:"pace.coach.model")
        status = "Déconnecté de cet iPhone."
        if let former {
            Task {
                let revoked = await revoke(former)
                if !revoked && !isConnected {
                    status = "Déconnecté localement. Révoque également PACE LAB depuis ChatGPT > Paramètres."
                }
            }
        }
    }
    private func revoke(_ session:PaceChatSession) async -> Bool {
        do {
            let (info,_) = try await URLSession.shared.data(
                from:URL(string:"https://auth.openai.com/.well-known/openid-configuration")!)
            guard let discovery = try JSONSerialization.jsonObject(with:info) as? [String:Any],
                  let string = discovery["revocation_endpoint"] as? String,
                  let endpoint = URL(string:string), endpoint.scheme == "https",
                  endpoint.host == "auth.openai.com" else { return false }
            var request = URLRequest(url:endpoint)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded",forHTTPHeaderField:"Content-Type")
            var form = URLComponents()
            form.queryItems = [
                .init(name:"client_id",value:session.clientID),
                .init(name:"token",value:session.refreshToken),
                .init(name:"token_type_hint",value:"refresh_token")
            ]
            request.httpBody = form.percentEncodedQuery?.data(using:.utf8)
            let (_,response) = try await URLSession.shared.data(for:request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch { return false }
    }
    private func fail(_ text:String) {
        browser = nil; loopback?.stop(); loopback = nil; pending = nil
        isBusy = false
        status = text
    }
}
private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString().replacingOccurrences(of:"+",with:"-")
            .replacingOccurrences(of:"/",with:"_")
            .replacingOccurrences(of:"=",with:"")
    }
}
